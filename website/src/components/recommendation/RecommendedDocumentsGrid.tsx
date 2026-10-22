'use client';

import React, { useState } from 'react';
import { useDocumentRecommendations } from '../../hooks/useDocumentRecommendations';
import { RecommendedDocument } from '../../types/document-module';
import { PhysicalLocationBadge } from '../location/PhysicalLocationBadge';
import { BorrowRequestModal } from '../borrow-share/BorrowRequestModal';

export const RecommendedDocumentsGrid: React.FC = () => {
  const { recommendations, isLoading, error, refetch } = useDocumentRecommendations(6);
  const [selectedDocForBorrow, setSelectedDocForBorrow] = useState<RecommendedDocument | null>(null);

  if (isLoading) {
    return (
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 py-6">
        {[1, 2, 3].map((n) => (
          <div key={n} className="bg-white rounded-2xl p-5 border border-slate-200 animate-pulse">
            <div className="h-4 bg-slate-200 rounded w-3/4 mb-3" />
            <div className="h-3 bg-slate-100 rounded w-1/2 mb-4" />
            <div className="h-20 bg-slate-50 rounded mb-4" />
            <div className="h-8 bg-slate-200 rounded" />
          </div>
        ))}
      </div>
    );
  }

  if (error) {
    return (
      <div className="p-4 bg-rose-50 border border-rose-200 rounded-xl text-rose-700 text-sm flex justify-between items-center">
        <span>Lỗi gợi ý: {error}</span>
        <button onClick={() => refetch()} className="underline font-semibold">Thử lại</button>
      </div>
    );
  }

  if (recommendations.length === 0) {
    return (
      <div className="text-center py-10 bg-slate-50 rounded-2xl border border-slate-200">
        <p className="text-slate-600 text-sm">Chưa có gợi ý phù hợp. Hãy đọc hoặc tương tác thêm tài liệu để hệ thống ghi nhận sở thích của bạn!</p>
      </div>
    );
  }

  return (
    <div>
      <div className="flex items-center justify-between mb-4">
        <div>
          <h2 className="text-xl font-bold text-slate-900 flex items-center gap-2">
            <span>✨ Gợi ý dành riêng cho bạn</span>
          </h2>
          <p className="text-xs text-slate-500 mt-0.5">
            Dựa trên các chủ đề và danh mục tài liệu bạn đã đọc hoặc mượn gần đây
          </p>
        </div>
        <button
          onClick={() => refetch()}
          className="text-xs text-blue-600 hover:text-blue-800 font-medium"
        >
          Làm mới
        </button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {recommendations.map((doc) => (
          <div
            key={doc.id}
            className="bg-white rounded-2xl p-5 border border-slate-200 hover:border-blue-300 hover:shadow-lg transition-all duration-200 flex flex-col justify-between"
          >
            <div>
              {/* Header card: Match score & Tags */}
              <div className="flex items-center justify-between mb-2">
                <span className="text-[11px] font-bold px-2 py-0.5 bg-blue-100 text-blue-800 rounded-full">
                  Khớp {(doc.similarity_score * 100).toFixed(0)}%
                </span>
                <span className="text-[11px] text-slate-400">
                  {new Date(doc.created_at).toLocaleDateString('vi-VN')}
                </span>
              </div>

              <h3 className="font-bold text-base text-slate-800 line-clamp-1 mb-1">
                {doc.title}
              </h3>

              <p className="text-xs text-slate-500 line-clamp-2 mb-3">
                {doc.description || 'Không có mô tả chi tiết'}
              </p>

              {/* Tag Overlap Indicator */}
              {doc.matched_tags && doc.matched_tags.length > 0 && (
                <div className="mb-3 p-2 bg-amber-50/70 rounded-lg border border-amber-200/60">
                  <span className="text-[11px] font-medium text-amber-800 block mb-1">
                    🎯 Chủ đề chung với bạn:
                  </span>
                  <div className="flex flex-wrap gap-1">
                    {doc.matched_tags.map((tag) => (
                      <span
                        key={tag}
                        className="text-[10px] bg-white text-amber-900 px-1.5 py-0.5 rounded border border-amber-200 font-semibold"
                      >
                        #{tag}
                      </span>
                    ))}
                  </div>
                </div>
              )}

              {/* Thông tin vị trí kho vật lý */}
              <div className="mb-4">
                <PhysicalLocationBadge location={doc} />
              </div>
            </div>

            {/* Actions */}
            <div className="pt-2 border-t border-slate-100 flex items-center justify-between gap-2">
              <button
                type="button"
                onClick={() => setSelectedDocForBorrow(doc)}
                className="w-full py-2 px-3 bg-blue-600 hover:bg-blue-700 text-white text-xs font-semibold rounded-lg shadow-sm transition"
              >
                Mượn tài liệu này
              </button>
            </div>
          </div>
        ))}
      </div>

      {/* Modal Mượn Tài Liệu */}
      {selectedDocForBorrow && (
        <BorrowRequestModal
          documentId={selectedDocForBorrow.id}
          documentTitle={selectedDocForBorrow.title}
          isOpen={!!selectedDocForBorrow}
          onClose={() => setSelectedDocForBorrow(null)}
          onSuccess={() => refetch()}
        />
      )}
    </div>
  );
};
