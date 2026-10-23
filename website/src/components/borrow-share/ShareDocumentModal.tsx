'use client';

import React, { useState } from 'react';
import { shareDocumentByEmail } from '../../services/borrowAndShareService';
import { SharePermission } from '../../types/document-module';

interface Props {
  documentId: string;
  documentTitle: string;
  isOpen: boolean;
  onClose: () => void;
  onSuccess?: () => void;
}

export const ShareDocumentModal: React.FC<Props> = ({
  documentId,
  documentTitle,
  isOpen,
  onClose,
  onSuccess,
}) => {
  const [email, setEmail] = useState('');
  const [permission, setPermission] = useState<SharePermission>('view');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [statusMessage, setStatusMessage] = useState<{ type: 'error' | 'success'; text: string } | null>(null);

  if (!isOpen) return null;

  const handleShare = async (e: React.FormEvent) => {
    e.preventDefault();
    setStatusMessage(null);
    setIsSubmitting(true);

    const { data, error } = await shareDocumentByEmail({
      documentId,
      email,
      permission,
    });

    setIsSubmitting(false);

    if (error) {
      setStatusMessage({ type: 'error', text: error.message });
    } else {
      setStatusMessage({ type: 'success', text: `Đã cấp quyền ${permission} cho ${email} thành công!` });
      setEmail('');
      onSuccess?.();
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
      <div className="w-full max-w-md bg-white rounded-2xl shadow-xl p-6 border border-slate-100">
        <div className="flex justify-between items-center mb-4">
          <h3 className="text-lg font-bold text-slate-800">Chia sẻ tài liệu</h3>
          <button onClick={onClose} className="text-slate-400 hover:text-slate-600">✕</button>
        </div>

        <p className="text-sm text-slate-600 mb-4 bg-slate-50 p-2.5 rounded-lg border border-slate-200">
          Tài liệu: <strong className="text-slate-900">{documentTitle}</strong>
        </p>

        {statusMessage && (
          <div
            className={`mb-4 text-xs p-3 rounded-lg border ${
              statusMessage.type === 'error'
                ? 'bg-red-50 text-red-600 border-red-200'
                : 'bg-green-50 text-green-700 border-green-200'
            }`}
          >
            {statusMessage.text}
          </div>
        )}

        <form onSubmit={handleShare} className="space-y-4 text-sm">
          <div>
            <label className="block font-medium text-slate-700 mb-1">Email người nhận</label>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="dongnghiep@company.com"
              required
              className="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none"
            />
          </div>

          <div>
            <label className="block font-medium text-slate-700 mb-1">Quyền truy cập</label>
            <select
              value={permission}
              onChange={(e) => setPermission(e.target.value as SharePermission)}
              className="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none"
            >
              <option value="view">Chỉ xem (View only)</option>
              <option value="edit">Xem & Chỉnh sửa (Full Edit)</option>
            </select>
          </div>

          <div className="flex justify-end gap-2 pt-2">
            <button
              type="button"
              onClick={onClose}
              disabled={isSubmitting}
              className="px-4 py-2 border rounded-lg text-slate-600 hover:bg-slate-50"
            >
              Đóng
            </button>
            <button
              type="submit"
              disabled={isSubmitting}
              className="px-5 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 disabled:opacity-50"
            >
              {isSubmitting ? 'Đang cấp quyền...' : 'Chia sẻ ngay'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
