'use server';

import { revalidatePath } from 'next/cache';
import { createClient } from '@/lib/supabase/server';

export async function createCategory(formData: FormData) {
  const supabase = await createClient();
  const stallId = String(formData.get('stall_id'));
  const { data: max } = await supabase
    .from('category')
    .select('sort_order')
    .eq('stall_id', stallId)
    .order('sort_order', { ascending: false })
    .limit(1)
    .maybeSingle();
  const { error } = await supabase.from('category').insert({
    stall_id: stallId,
    name: String(formData.get('name')),
    sort_order: (max?.sort_order ?? 0) + 1,
  });
  if (error) throw new Error(error.message);
  revalidatePath('/menu');
}

export async function renameCategory(id: string, name: string) {
  const supabase = await createClient();
  const { error } = await supabase.from('category').update({ name }).eq('id', id);
  if (error) throw new Error(error.message);
  revalidatePath('/menu');
}

export async function moveCategory(id: string, stallId: string, dir: -1 | 1) {
  const supabase = await createClient();
  const { data: cats } = await supabase
    .from('category')
    .select('id, sort_order')
    .eq('stall_id', stallId)
    .order('sort_order');
  const list = cats ?? [];
  const i = list.findIndex((c) => c.id === id);
  const j = i + dir;
  if (i < 0 || j < 0 || j >= list.length) return;
  const a = list[i];
  const b = list[j];
  await supabase.from('category').update({ sort_order: b.sort_order }).eq('id', a.id);
  await supabase.from('category').update({ sort_order: a.sort_order }).eq('id', b.id);
  revalidatePath('/menu');
}


export async function deleteCategory(formData: FormData) {
  const supabase = await createClient();
  const id = String(formData.get('id'));
  const reassignTo = String(formData.get('reassign_to') || '').trim();

  const { count } = await supabase
    .from('menu_item')
    .select('id', { count: 'exact', head: true })
    .eq('category_id', id);

  if ((count ?? 0) > 0) {
    if (!reassignTo) {
      throw new Error('reassign items to another category before deleting');
    }
    const { error: moveErr } = await supabase
      .from('menu_item')
      .update({ category_id: reassignTo })
      .eq('category_id', id);
    if (moveErr) throw new Error(moveErr.message);
  }

  const { error } = await supabase.from('category').delete().eq('id', id);
  if (error) throw new Error(error.message);
  revalidatePath('/menu');
}

export async function createItem(formData: FormData) {
  const supabase = await createClient();
  const categoryId = String(formData.get('category_id') || '');
  const parentId = String(formData.get('parent_id') || '').trim();
  const quick = String(formData.get('quick_code') || '').trim();
  const { error } = await supabase.from('menu_item').insert({
    stall_id: String(formData.get('stall_id')),
    name: String(formData.get('name')),
    price: Number(formData.get('price')),
    description: String(formData.get('description') || '') || null,
    category_id: categoryId || null,
    quick_code: quick || null,
    parent_id: parentId || null,
  });
  if (error) throw new Error(error.message);
  revalidatePath('/menu');
}

export async function updateItem(formData: FormData) {
  const supabase = await createClient();
  const id = String(formData.get('id'));
  const categoryId = String(formData.get('category_id') || '');
  const { error } = await supabase
    .from('menu_item')
    .update({
      name: String(formData.get('name')),
      price: Number(formData.get('price')),
      description: String(formData.get('description') || '') || null,
      category_id: categoryId || null,
      quick_code: String(formData.get('quick_code') || '').trim() || null,
      parent_id: String(formData.get('parent_id') || '').trim() || null,
    })
    .eq('id', id);
  if (error) throw new Error(error.message);
  revalidatePath('/menu');
}

export async function deleteItem(id: string) {
  const supabase = await createClient();
  const { error } = await supabase.from('menu_item').delete().eq('id', id);
  if (error) throw new Error(error.message);
  revalidatePath('/menu');
}

export async function duplicateItem(id: string) {
  const supabase = await createClient();
  const { data: item, error: readErr } = await supabase
    .from('menu_item')
    .select('stall_id, category_id, name, description, price')
    .eq('id', id)
    .single();
  if (readErr || !item) throw new Error(readErr?.message ?? 'not found');
  const { error } = await supabase.from('menu_item').insert({
    ...item,
    name: `${item.name} (copy)`,
  });
  if (error) throw new Error(error.message);
  revalidatePath('/menu');
}

export async function toggleAvailability(id: string, next: boolean) {
  const supabase = await createClient();
  const { error } = await supabase
    .from('menu_item')
    .update({ is_available: next })
    .eq('id', id);
  if (error) throw new Error(error.message);
  revalidatePath('/menu');
}

export async function uploadItemImage(formData: FormData) {
  const supabase = await createClient();
  const stallId = String(formData.get('stall_id'));
  const itemId = String(formData.get('item_id'));
  const file = formData.get('image');
  if (!(file instanceof File) || file.size === 0) {
    throw new Error('image required');
  }
  const ext = (file.name.split('.').pop() || 'jpg').toLowerCase().replace(/[^a-z0-9]/g, '');
  const path = `${stallId}/${itemId}.${ext}`;
  const buf = Buffer.from(await file.arrayBuffer());
  const { error: upErr } = await supabase.storage
    .from('menu-images')
    .upload(path, buf, { contentType: file.type || 'image/jpeg', upsert: true });
  if (upErr) throw new Error(upErr.message);
  const { data } = supabase.storage.from('menu-images').getPublicUrl(path);
  const { error } = await supabase
    .from('menu_item')
    .update({ image_url: data.publicUrl })
    .eq('id', itemId);
  if (error) throw new Error(error.message);
  revalidatePath('/menu');
}

export async function clearItemImage(itemId: string) {
  const supabase = await createClient();
  const { error } = await supabase
    .from('menu_item')
    .update({ image_url: null })
    .eq('id', itemId);
  if (error) throw new Error(error.message);
  revalidatePath('/menu');
}

// --- Tables ---------------------------------------------------------------
// Lives here rather than in settings/: /settings is owner-only in the sidebar,
// but restaurant_table RLS allows owner *and* manager, same as menu_item.

export async function addTable(formData: FormData) {
  const supabase = await createClient();
  const label = String(formData.get('label') || '').trim();
  if (!label) throw new Error('label required');
  const seatsRaw = String(formData.get('seats') || '').trim();
  const seats = seatsRaw ? Number(seatsRaw) : null;
  if (seats !== null && (!Number.isInteger(seats) || seats <= 0)) {
    throw new Error('seats must be a positive whole number');
  }
  const { error } = await supabase.from('restaurant_table').insert({
    stall_id: String(formData.get('stall_id')),
    label,
    seats,
  });
  if (error) {
    throw new Error(
      error.code === '23505' ? `A table called "${label}" already exists` : error.message,
    );
  }
  revalidatePath('/menu');
}

export async function setTableActive(id: string, isActive: boolean) {
  const supabase = await createClient();
  const { error } = await supabase
    .from('restaurant_table')
    .update({ is_active: isActive })
    .eq('id', id);
  if (error) throw new Error(error.message);
  revalidatePath('/menu');
}

export async function deleteTable(id: string) {
  const supabase = await createClient();
  const { error } = await supabase.from('restaurant_table').delete().eq('id', id);
  if (error) throw new Error(error.message);
  revalidatePath('/menu');
}
