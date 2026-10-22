'use client';

import React, { useState } from 'react';
import { createBorrowRequest } from '../../services/borrowAndShareService';

interface Props {
  documentId: string;
  documentTitle: string;
  isOpen: boolean;
  onClose: () => void;
  onSuccess?: () => void;
}

export const BorrowRequestModal: React.FC<Props> = ({
  documentId,
  documentTitle,
  isOpen,
  onClose,
  onSuccess,
}) => {
  const [borrowDate, setBorrowDate] = useState<string>(
    new Date().toISOString().split('T')[0]
  );
  // Mặc định hẹn trả sau 7 ngày
  const [dueDate, setDueDate] = useState<string>(
    new Date(Date.now() + 7 * 86400000).toISOString().split('T')[0]
  );
  const [notes, setNotes] = useState<string>('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  if (!isOpen) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMessage(null);

    if (new Date(dueDate) < new Date(borrowDate)) {
      setErrorMessage('Ngày hẹn trả phải sau hoặc cùng ngày mượn.');
      return;
    }

    setIsSubmitting(true);
    const { error } = await createBorrowRequest({
      documentId,
      borrowDate: new Date(borrowDate).toISOString(),
      dueDate: new Date(dueDate).toISOString(),
      notes,
    });

    setIsSubmitting(false);

    if (error) {
      setErrorMessage(error.message);
    } else {
      alert('Gửi yêu cầu mượn thành công! Vui lòng chờ chủ sở hữu duyệt.');
      onSuccess?.();
      onClose();
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
      <div className="w-full max-w-md bg-white rounded-2xl shadow-xl p-6 border border-slate-100">
        <div className="flex justify-between items-center mb-4">
          <h3 className="text-lg font-bold text-slate-800">Yêu cầu mượn tài liệu</h3>
          <button onClick={onClose} className="text-slate-400 hover:text-slate-600">✕</button>
        </div>

        <p className="text-sm text-slate-600 mb-4 bg-slate-50 p-2.5 rounded-lg border border-slate-200">
          Tài liệu: <strong className="text-slate-900">{documentTitle}</strong>
        </p>

        {errorMessage && (
          <div className="mb-4 text-xs bg-red-50 text-red-600 p-3 rounded-lg border border-red-200">
            {errorMessage}
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-4 text-sm">
          <div>
            <label className="block font-medium text-slate-700 mb-1">Ngày bắt đầu mượn</label>
            <input
              type="date"
              value={borrowDate}
              onChange={(e) => setBorrowDate(e.target.value)}
              required
              className="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 outline-none"
            />
          </div>

          <div>
            <label className="block font-medium text-slate-700 mb-1">Ngày hẹn trả</label>
            <input
              type="date"
              value={dueDate}
              onChange={(e) => setDueDate(e.target.value)}
              required
              className="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 outline-none"
            />
          </div>

          <div>
            <label className="block font-medium text-slate-700 mb-1">Mục đích / Ghi chú</label>
            <textarea
              rows={3}
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              placeholder="VD: Phục vụ nghiên cứu khóa luận, mượn tại phòng lưu trữ hồ sơ..."
              className="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 outline-none"
            />
          </div>

          <div className="flex justify-end gap-2 pt-2">
            <button
              type="button"
              onClick={onClose}
              disabled={isSubmitting}
              className="px-4 py-2 border rounded-lg text-slate-600 hover:bg-slate-50"
            >
              Hủy
            </button>
            <button
              type="submit"
              disabled={isSubmitting}
              className="px-5 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50"
            >
              {isSubmitting ? 'Đang gửi...' : 'Gửi yêu cầu'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
