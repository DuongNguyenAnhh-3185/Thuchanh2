'use client';

import React, { useEffect, useRef } from 'react';

interface Props {
  latitude: number;
  longitude: number;
  popupTitle?: string;
  popupDescription?: string;
  height?: string;
}

export const DocumentLocationMap: React.FC<Props> = ({
  latitude,
  longitude,
  popupTitle = 'Vị trí kho tài liệu',
  popupDescription,
  height = '320px',
}) => {
  const mapContainerRef = useRef<HTMLDivElement>(null);
  const mapInstanceRef = useRef<any>(null);

  useEffect(() => {
    let isMounted = true;

    // Load leaflet động trên client để tránh lỗi SSR "window is not defined"
    const initMap = async () => {
      const L = (await import('leaflet')).default;
      try {
        await import('leaflet/dist/leaflet.css');
      } catch {
        // Ignored if css is loaded via global stylesheet
      }

      if (!mapContainerRef.current || !isMounted) return;

      // Hủy map cũ nếu đã tồn tại để tránh re-init error
      if (mapInstanceRef.current) {
        mapInstanceRef.current.remove();
      }

      // Khởi tạo map
      const map = L.map(mapContainerRef.current).setView([latitude, longitude], 15);
      mapInstanceRef.current = map;

      // Dùng OpenStreetMap Tile Server (Hoàn toàn miễn phí, không cần token)
      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '&copy; OpenStreetMap contributors',
        maxZoom: 19,
      }).addTo(map);

      // Tùy chỉnh Icon để khắc phục lỗi thiếu asset mặc định của bundler
      const customIcon = L.icon({
        iconUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png',
        iconRetinaUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png',
        shadowUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png',
        iconSize: [25, 41],
        iconAnchor: [12, 41],
        popupAnchor: [1, -34],
        shadowSize: [41, 41],
      });

      const marker = L.marker([latitude, longitude], { icon: customIcon }).addTo(map);
      marker.bindPopup(`
        <div style="font-family: sans-serif; font-size: 13px;">
          <b style="color: #1e3a8a;">${popupTitle}</b>
          ${popupDescription ? `<p style="margin: 4px 0 0; color: #475569;">${popupDescription}</p>` : ''}
          <div style="margin-top: 6px; font-size: 11px; color: #64748b;">
            Tọa độ: ${latitude.toFixed(5)}, ${longitude.toFixed(5)}
          </div>
        </div>
      `).openPopup();
    };

    initMap();

    return () => {
      isMounted = false;
      if (mapInstanceRef.current) {
        mapInstanceRef.current.remove();
        mapInstanceRef.current = null;
      }
    };
  }, [latitude, longitude, popupTitle, popupDescription]);

  return (
    <div className="overflow-hidden rounded-xl border border-slate-300 shadow-sm relative">
      <div ref={mapContainerRef} style={{ height, width: '100%' }} />
    </div>
  );
};
