export type SharePermission = 'view' | 'edit';
export type BorrowStatus = 'pending' | 'approved' | 'rejected' | 'returned';

export interface PhysicalLocation {
  storage_room?: string | null;
  shelf_code?: string | null;
  box_number?: string | null;
  latitude?: number | null;
  longitude?: number | null;
  address?: string | null;
}

export interface DocumentItem extends PhysicalLocation {
  id: string;
  owner_id: string;
  title: string;
  description?: string;
  file_name: string;
  tags?: string[];
  created_at: string;
}

export interface DocumentShare {
  id: string;
  document_id: string;
  user_id: string;
  permission: SharePermission;
  created_at: string;
}

export interface BorrowRequest {
  id: string;
  document_id: string;
  requester_id: string;
  status: BorrowStatus;
  borrow_date: string;
  due_date: string;
  notes?: string | null;
  created_at: string;
  // Join fields
  document?: {
    id: string;
    title: string;
    shelf_code?: string;
    storage_room?: string;
  };
  requester?: {
    id: string;
    email?: string;
    display_name?: string;
  };
}

export interface RecommendedDocument extends DocumentItem {
  matched_tags: string[];
  similarity_score: number;
}
