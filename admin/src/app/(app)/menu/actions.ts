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

export async function createItem(formData: FormData) {
  const supabase = await createClient();
  const categoryId = String(formData.get('category_id') || '');
  const { error } = await supabase.from('menu_item').insert({
    stall_id: String(formData.get('stall_id')),
    name: String(formData.get('name')),
    price: Number(formData.get('price')),
    description: String(formData.get('description') || '') || null,
    category_id: categoryId || null,
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
