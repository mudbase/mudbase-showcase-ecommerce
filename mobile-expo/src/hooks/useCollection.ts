import { useMutation, useQuery, useQueryClient, type UseQueryOptions } from "@tanstack/react-query";
import { z } from "zod";
import { mudbaseClient } from "@/api/client";

interface ListParams {
  filter?: Record<string, unknown>;
  sort?: string;
  page?: number;
  limit?: number;
}

/** Generic list-documents hook — mirrors web/src/hooks/useCollection.ts's useDocuments, backed by the real DataApi. */
export function useDocuments<T>(
  schema: z.ZodType<T>,
  collectionId: string,
  params?: ListParams,
  options?: Omit<UseQueryOptions<{ data: T[]; pagination: unknown }>, "queryKey" | "queryFn">,
) {
  return useQuery({
    queryKey: ["collection", collectionId, params ?? {}],
    queryFn: () => mudbaseClient.listDocuments(schema, collectionId, params),
    ...options,
  });
}

export function useDocument<T>(
  schema: z.ZodType<T>,
  collectionId: string,
  documentId: string | null | undefined,
  options?: Omit<UseQueryOptions<T>, "queryKey" | "queryFn" | "enabled">,
) {
  return useQuery({
    queryKey: ["collection", collectionId, "doc", documentId],
    queryFn: () => {
      if (!documentId) throw new Error("useDocument called without a documentId");
      return mudbaseClient.getDocument(schema, collectionId, documentId);
    },
    enabled: !!documentId,
    ...options,
  });
}

export function useCreateDocument<T extends { _id: string }>(schema: z.ZodType<T>, collectionId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (data: Record<string, unknown>) => mudbaseClient.createDocument(schema, collectionId, data),
    onSuccess: (created: T) => {
      void queryClient.invalidateQueries({ queryKey: ["collection", collectionId] });
      queryClient.setQueryData(["collection", collectionId, "doc", created._id], created);
    },
  });
}

export function useUpdateDocument<T>(schema: z.ZodType<T>, collectionId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: { documentId: string; data: Record<string, unknown> }) =>
      mudbaseClient.updateDocument(schema, collectionId, input.documentId, input.data),
    onSuccess: (updated: T, variables: { documentId: string; data: Record<string, unknown> }) => {
      queryClient.setQueryData(["collection", collectionId, "doc", variables.documentId], updated);
      void queryClient.invalidateQueries({ queryKey: ["collection", collectionId] });
    },
  });
}

export function useDeleteDocument(collectionId: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (documentId: string) => mudbaseClient.deleteDocument(collectionId, documentId),
    onSuccess: (_result: void, documentId: string) => {
      queryClient.removeQueries({ queryKey: ["collection", collectionId, "doc", documentId] });
      void queryClient.invalidateQueries({ queryKey: ["collection", collectionId] });
    },
  });
}
