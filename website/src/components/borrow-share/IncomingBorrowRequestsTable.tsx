'use client';

import React, { useEffect, useState } from 'react';
import {
  getIncomingBorrowRequests,
  updateBorrowRequestStatus,
} from '../../services/borrowAndShareService';
import { BorrowRequest, BorrowStatus } from '../../types/document-module';

export const IncomingBorrowRequestsTable: React.FC = () => {
  const [requests, setRequests] = useState<BorrowRequest[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [processingId, setProcessingId] = useState<string | null>(null);

  const loadRequests = async () => {
    setIsLoading(true);
    const { data } = await getIncomingBorrowRequests();
    setRequests(data);
    setIsLoading(false);
  };

  useEffect(() => {
    loadRequests();
  }, []);

  const handleAction = async (requestId: string, newStatus: BorrowStatus) => {
    setProcessingId(requestId);
    const { success, error } = await updateBorrowRequestStatus(requestId, newStatus);
    setProcessingId(null);

    if (success) {
      setRequests((prev) =>
        prev.map((r) => (r.id === requestId ? { ...r, status: newStatus } : r))
      );
    } else {
      alert(`Thất bại: ${error?.message}`);
    }
  };

  const getStatusBadge = (status: BorrowStatus) => {
    const config: Record<BorrowStatus, { bg: string; text: string; label: string }> = {
      pending: { bg: 'bg-amber-100', text: 'text-amber-800', label: 'Chờ duyệt' },
      approved: { bg: 'bg-emerald-100', text: 'text-emerald-800', label: 'Đang mượn' },
      rejected: { bg: 'bg-rose-100', text: 'text-rose-800', label: 'Từ chối' },
      returned: { bg: 'bg-slate-100', text: 'text-slate-800', label: 'Đã hoàn trả' },
    };
    const c = config[status];
    return (
      <span className={`inline-block px-2.5 py-1 text-xs font-semibold rounded-full ${c.bg} ${c.text}`}>
        {c.label}
      </span>
    );
  };

  if (isLoading) {
    return (
      <div className="p-8 text-center text-slate-500">
        <div className="inline-block animate-spin rounded-full h-6 w-6 border-2 border-blue-600 border-t-transparent mb-2"></div>
        <p className="text-sm">Đang tải danh sách yêu cầu mượn...</p>
      </div>
    );
  }

  if (requests.length === 0) {
    return (
      <div className="p-8 text-center bg-slate-50 rounded-xl border border-dashed border-slate-300 text-slate-500">
        Hiện tại không có yêu cầu mượn nào cần xử lý.
      </div>
    );
  }

  return (
    <div className="overflow-x-auto rounded-xl border border-slate-200 shadow-sm">
      <table className="w-full text-left text-sm text-slate-600">
        <thead className="bg-slate-100 text-xs uppercase text-slate-500 border-b border-slate-200">
          <tr>
            <th className="px-4 py-3">Tài liệu</th>
            <th className="px-4 py-3">Vị trí kho</th>
            <th className="px-4 py-3">Thời gian mượn</th>
            <th className="px-4 py-3">Ghi chú</th>
            <th className="px-4 py-3">Trạng thái</th>
            <th className="px-4 py-3 text-right">Thao tác</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-slate-200 bg-white">
          {requests.map((req) => (
            <tr key={req.id} className="hover:bg-slate-50/80 transition">
              <td className="px-4 py-3 font-medium text-slate-900">
                {req.document?.title || req.document_id}
              </td>
              <td className="px-4 py-3 text-xs">
                {req.document?.storage_room ? (
                  <span className="text-slate-700">
                    Phòng: {req.document.storage_room} | Kệ: {req.document.shelf_code || '---'}
                  </span>
                ) : (
                  <span className="text-slate-400">---</span>
                )}
              </td>
              <td className="px-4 py-3 text-xs">
                <div>Từ: {new Date(req.borrow_date).toLocaleDateString('vi-VN')}</div>
                <div className="text-rose-600 font-medium">
                  Hạn: {new Date(req.due_date).toLocaleDateString('vi-VN')}
                </div>
              </td>
              <td className="px-4 py-3 text-xs max-w-xs truncate text-slate-500">
                {req.notes || 'Không có ghi chú'}
              </td>
              <td className="px-4 py-3">{getStatusBadge(req.status)}</td>
              <td className="px-4 py-3 text-right space-x-1.5 whitespace-nowrap">
                {req.status === 'pending' && (
                  <>
                    <button
                      onClick={() => handleAction(req.id, 'approved')}
                      disabled={processingId === req.id}
                      className="px-2.5 py-1 text-xs font-medium bg-emerald-600 text-white rounded hover:bg-emerald-700 disabled:opacity-50"
                    >
                      Duyệt
                    </button>
                    <button
                      onClick={() => handleAction(req.id, 'rejected')}
                      disabled={processingId === req.id}
                      className="px-2.5 py-1 text-xs font-medium bg-rose-600 text-white rounded hover:bg-rose-700 disabled:opacity-50"
                    >
                      Từ chối
                    </button>
                  </>
                )}

                {req.status === 'approved' && (
                  <button
                    onClick={() => handleAction(req.id, 'returned')}
                    disabled={processingId === req.id}
                    className="px-2.5 py-1 text-xs font-medium bg-blue-600 text-white rounded hover:bg-blue-700 disabled:opacity-50"
                  >
                    Đã nhận lại sách
                  </button>
                )}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
};
