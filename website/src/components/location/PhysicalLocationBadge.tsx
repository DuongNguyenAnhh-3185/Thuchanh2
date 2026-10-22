'use client';

import React from 'react';
import { PhysicalLocation } from '../../types/document-module';

interface Props {
  location: PhysicalLocation;
  showMapButton?: boolean;
  onOpenMap?: () => void;
}

export const PhysicalLocationBadge: React.FC<Props> = ({
  location,
  showMapButton = false,
  onOpenMap,
}) => {
  const hasCoordinates = !!(location.latitude && location.longitude);
  const hasPhysicalInfo = !!(location.storage_room || location.shelf_code || location.box_number);

  if (!hasPhysicalInfo && !hasCoordinates && !location.address) {
    return (
      <span className="text-xs italic text-gray-400">
        Chưa cập nhật vị trí lưu kho
      </span>
    );
  }

  return (
    <div className="bg-slate-50 border border-slate-200 rounded-lg p-3 text-sm text-slate-700 shadow-sm">
      <div className="flex items-center gap-1.5 font-semibold text-slate-800 mb-2">
        <svg className="w-4 h-4 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
        </svg>
        <span>Vị trí lưu kho vật lý:</span>
      </div>

      <div className="grid grid-cols-3 gap-2 text-center text-xs">
        <div className="bg-white p-1.5 rounded border border-slate-200">
          <span className="block text-slate-400 font-medium">Phòng/Kho</span>
          <span className="font-semibold text-slate-800">{location.storage_room || '---'}</span>
        </div>
        <div className="bg-white p-1.5 rounded border border-blue-200 bg-blue-50/50">
          <span className="block text-blue-500 font-medium">Kệ/Tủ</span>
          <span className="font-bold text-blue-700">{location.shelf_code || '---'}</span>
        </div>
        <div className="bg-white p-1.5 rounded border border-slate-200">
          <span className="block text-slate-400 font-medium">Hộp/Khay</span>
          <span className="font-semibold text-slate-800">{location.box_number || '---'}</span>
        </div>
      </div>

      {location.address && (
        <div className="mt-2 text-xs text-slate-500 flex items-start gap-1">
          <svg className="w-3.5 h-3.5 text-slate-400 mt-0.5 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
          </svg>
          <span className="truncate">{location.address}</span>
        </div>
      )}

      {showMapButton && hasCoordinates && (
        <button
          type="button"
          onClick={onOpenMap}
          className="mt-2.5 w-full inline-flex items-center justify-center gap-1.5 text-xs text-blue-600 font-medium hover:text-blue-800 hover:bg-blue-50 py-1 rounded transition"
        >
          <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 20l-5.447-2.724A1 1 0 013 16.382V5.618a1 1 0 011.447-.894L9 7m0 13l6-3m-6 3V7m6 10l4.553 2.276A1 1 0 0021 18.382V7.618a1 1 0 00-.553-.894L15 4m0 13V4m0 0L9 7" />
          </svg>
          Xem vị trí trên bản đồ
        </button>
      )}
    </div>
  );
};
