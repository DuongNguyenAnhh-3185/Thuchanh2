import { BorrowRequest, BorrowStatus, SharePermission } from '../types/document-module';

// Tùy biến Supabase client: tương thích với @supabase/auth-helpers-nextjs hoặc @supabase/supabase-js
let supabaseClient: any = null;

export function setSupabaseClient(client: any) {
  supabaseClient = client;
}

export function getSupabaseClient() {
  if (supabaseClient) return supabaseClient;
  // Fallback dynamic import hoặc window Supabase nếu có
  if (typeof window !== 'undefined' && (window as any).supabase) {
    return (window as any).supabase;
  }
  try {
    const { createClientComponentClient } = require('@supabase/auth-helpers-nextjs');
    supabaseClient = createClientComponentClient();
    return supabaseClient;
  } catch {
    throw new Error('Chưa khởi tạo Supabase Client. Vui lòng gọi setSupabaseClient(client).');
  }
}

/**
 * 1. Gửi yêu cầu mượn tài liệu
 */
export async function createBorrowRequest(params: {
  documentId: string;
  borrowDate: string;
  dueDate: string;
  notes?: string;
}): Promise<{ data: BorrowRequest | null; error: Error | null }> {
  try {
    const supabase = getSupabaseClient();
    const { data: { user }, error: userError } = await supabase.auth.getUser();
    if (userError || !user) throw new Error('Vui lòng đăng nhập để mượn tài liệu.');

    const { data, error } = await supabase
      .from('borrow_requests')
      .insert({
        document_id: params.documentId,
        requester_id: user.id,
        borrow_date: params.borrowDate,
        due_date: params.dueDate,
        notes: params.notes || null,
        status: 'pending',
      })
      .select()
      .single();

    if (error) throw error;
    return { data, error: null };
  } catch (err: any) {
    return { data: null, error: err };
  }
}

/**
 * 2. Cập nhật trạng thái yêu cầu mượn (Duyệt, từ chối, đã trả)
 */
export async function updateBorrowRequestStatus(
  requestId: string,
  newStatus: BorrowStatus
): Promise<{ success: boolean; error: Error | null }> {
  try {
    const supabase = getSupabaseClient();
    const { error } = await supabase
      .from('borrow_requests')
      .update({ status: newStatus })
      .eq('id', requestId);

    if (error) throw error;
    return { success: true, error: null };
  } catch (err: any) {
    return { success: false, error: err };
  }
}

/**
 * 3. Chia sẻ quyền tài liệu qua Email bằng Postgres RPC
 */
export async function shareDocumentByEmail(params: {
  documentId: string;
  email: string;
  permission: SharePermission;
}): Promise<{ data: any; error: Error | null }> {
  try {
    const supabase = getSupabaseClient();
    const { data, error } = await supabase.rpc('share_document_by_email', {
      p_document_id: params.documentId,
      p_email: params.email.trim(),
      p_permission: params.permission,
    });

    if (error) throw error;
    return { data, error: null };
  } catch (err: any) {
    return { data: null, error: err };
  }
}

/**
 * 4. Lấy danh sách các yêu cầu mượn gửi đến cho tài liệu của tôi (dành cho chủ tài liệu)
 */
export async function getIncomingBorrowRequests(): Promise<{
  data: BorrowRequest[];
  error: Error | null;
}> {
  try {
    const supabase = getSupabaseClient();
    const { data, error } = await supabase
      .from('borrow_requests')
      .select(`
        id,
        document_id,
        requester_id,
        status,
        borrow_date,
        due_date,
        notes,
        created_at,
        document:documents (
          id,
          title,
          shelf_code,
          storage_room
        )
      `)
      .order('created_at', { ascending: false });

    if (error) throw error;
    return { data: (data as any) || [], error: null };
  } catch (err: any) {
    return { data: [], error: err };
  }
}
