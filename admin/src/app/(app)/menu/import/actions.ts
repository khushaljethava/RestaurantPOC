'use server';

import { revalidatePath } from 'next/cache';
import { createClient } from '@/lib/supabase/server';
import { parseCsv } from '@/lib/csv';

export type ImportResult = {
  created: number;
  updated: number;
  errors: { row: number; message: string }[];
};

/**
 * CSV columns (header row): name, price, category, quick_code, description, available
 * Match existing items by quick_code (preferred) or name within stall.
 */
export async function importMenuCsv(formData: FormData): Promise<ImportResult> {
  const stallId = String(formData.get('stall_id') || '');
  const file = formData.get('file');
  if (!stallId) throw new Error('stall required');
  if (!(file instanceof File) || file.size === 0) throw new Error('CSV file required');

  const text = await file.text();
  const { headers, rows } = parseCsv(text);
  const idx = (name: string) => headers.indexOf(name);
  const iName = idx('name');
  const iPrice = idx('price');
  if (iName < 0 || iPrice < 0) {
    throw new Error('CSV must include name and price columns');
  }
  const iCat = idx('category');
  const iCode = idx('quick_code');
  const iDesc = idx('description');
  const iAvail = idx('available');

  const supabase = await createClient();
  const { data: cats } = await supabase
    .from('category')
    .select('id, name')
    .eq('stall_id', stallId);
  const catByName = new Map((cats ?? []).map((c) => [c.name.toLowerCase(), c.id]));

  const { data: items } = await supabase
    .from('menu_item')
    .select('id, name, quick_code')
    .eq('stall_id', stallId)
    .is('parent_id', null);
  const byCode = new Map(
    (items ?? []).filter((i) => i.quick_code).map((i) => [String(i.quick_code), i.id])
  );
  const byName = new Map((items ?? []).map((i) => [i.name.toLowerCase(), i.id]));

  let created = 0;
  let updated = 0;
  const errors: { row: number; message: string }[] = [];

  for (let r = 0; r < rows.length; r++) {
    const row = rows[r];
    const name = (row[iName] ?? '').trim();
    const price = Number(row[iPrice]);
    if (!name) {
      errors.push({ row: r + 2, message: 'name required' });
      continue;
    }
    if (!Number.isFinite(price) || price < 0) {
      errors.push({ row: r + 2, message: 'invalid price' });
      continue;
    }

    let categoryId: string | null = null;
    if (iCat >= 0 && row[iCat]?.trim()) {
      const cname = row[iCat].trim();
      const key = cname.toLowerCase();
      if (catByName.has(key)) categoryId = catByName.get(key)!;
      else {
        const { data: createdCat, error } = await supabase
          .from('category')
          .insert({ stall_id: stallId, name: cname, sort_order: catByName.size + 1 })
          .select('id, name')
          .single();
        if (error) {
          errors.push({ row: r + 2, message: error.message });
          continue;
        }
        categoryId = createdCat.id;
        catByName.set(key, createdCat.id);
      }
    }

    const code = iCode >= 0 ? row[iCode]?.trim() || null : null;
    const description = iDesc >= 0 ? row[iDesc]?.trim() || null : null;
    const availRaw = iAvail >= 0 ? (row[iAvail] ?? '').trim().toLowerCase() : '';
    const is_available =
      availRaw === '' || availRaw === '1' || availRaw === 'true' || availRaw === 'yes';

    const existingId =
      (code && byCode.get(code)) || byName.get(name.toLowerCase()) || null;

    if (existingId) {
      const { error } = await supabase
        .from('menu_item')
        .update({
          name,
          price,
          category_id: categoryId,
          quick_code: code,
          description,
          is_available,
        })
        .eq('id', existingId);
      if (error) errors.push({ row: r + 2, message: error.message });
      else updated++;
    } else {
      const { data: createdItem, error } = await supabase
        .from('menu_item')
        .insert({
          stall_id: stallId,
          name,
          price,
          category_id: categoryId,
          quick_code: code,
          description,
          is_available,
        })
        .select('id, name, quick_code')
        .single();
      if (error) errors.push({ row: r + 2, message: error.message });
      else {
        created++;
        byName.set(name.toLowerCase(), createdItem.id);
        if (createdItem.quick_code) byCode.set(createdItem.quick_code, createdItem.id);
      }
    }
  }

  revalidatePath('/menu');
  revalidatePath('/menu/import');
  revalidatePath('/menu/availability');
  return { created, updated, errors };
}
