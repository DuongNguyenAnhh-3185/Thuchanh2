'use client';

import { useState, useEffect, useCallback } from 'react';
import { getSupabaseClient } from '../services/borrowAndShareService';
import { RecommendedDocument } from '../types/document-module';

export function useDocumentRecommendations(limitCount = 6) {
  const [recommendations, setRecommendations] = useState<RecommendedDocument[]>([]);
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);

  const fetchRecommendations = useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      const supabase = getSupabaseClient();
      const { data: { user }, error: authErr } = await supabase.auth.getUser();
      if (authErr || !user) {
        setIsLoading(false);
        return;
      }

      const { data, error: rpcErr } = await supabase.rpc('get_recommended_documents', {
        target_user_id: user.id,
        limit_count: limitCount,
      });

      if (rpcErr) throw rpcErr;
      setRecommendations(data || []);
    } catch (err: any) {
      setError(err.message || 'Lỗi tải danh sách gợi ý tài liệu');
    } finally {
      setIsLoading(false);
    }
  }, [limitCount]);

  useEffect(() => {
    fetchRecommendations();
  }, [fetchRecommendations]);

  return { recommendations, isLoading, error, refetch: fetchRecommendations };
}
