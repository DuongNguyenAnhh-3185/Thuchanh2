-- ============================================================
-- CashewDoc — Supabase Schema Setup
-- Chạy script này trong Supabase SQL Editor:
-- https://oemlhoqptgrgtwaozmgu.supabase.co
-- ============================================================

-- Bảng lưu trữ tài liệu học tập đám mây
CREATE TABLE IF NOT EXISTS cloud_documents (
  id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  local_id      TEXT,                         -- ID từ SQLite cục bộ (dùng để sync)
  title         TEXT NOT NULL,
  document_type TEXT NOT NULL DEFAULT 'Bài giảng (Lecture)',
  study_status  TEXT NOT NULL DEFAULT 'Chưa học',
  note          TEXT DEFAULT '',
  tags          TEXT DEFAULT '',
  priority      INTEGER NOT NULL DEFAULT 2,
  owner_email   TEXT DEFAULT '',
  owner_name    TEXT DEFAULT '',
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

-- Index tăng tốc truy vấn theo ngày tạo và local_id
CREATE INDEX IF NOT EXISTS idx_cloud_documents_created_at
  ON cloud_documents(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_cloud_documents_local_id
  ON cloud_documents(local_id)
  WHERE local_id IS NOT NULL;

-- Bật Realtime cho bảng này
ALTER PUBLICATION supabase_realtime ADD TABLE cloud_documents;

-- Chính sách RLS (Row Level Security) — tạm thời mở để test
ALTER TABLE cloud_documents ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all for now"
  ON cloud_documents
  FOR ALL
  USING (true)
  WITH CHECK (true);
