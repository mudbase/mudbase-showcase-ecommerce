import { isAxiosError, type AxiosResponse } from "axios";
import {
  AuthenticationApi,
  Configuration,
  DataApi,
  MultiRoleFeatureApi,
  type RegisterWithRoleRequest,
} from "mudbase-sdk";
import { z } from "zod";
import { MUDBASE_PROJECT_ID, MUDBASE_URL } from "@/config/env";
import { secureStorage, STORAGE_KEYS } from "./secureStorage";
import { authResultSchema, mudbaseUserSchema, type AuthResult, type MudbaseUser } from "./schemas";

/**
 * Thin, typed wrapper around the real generated `mudbase-sdk` — NOT a
 * unified client the SDK doesn't have. Every call below is a real generated
 * method (`AuthenticationApi`/`MultiRoleFeatureApi`/`DataApi` instances, one
 * per resource — see the "SDK dependency" note in README.md). This file only
 * adds: token storage (SecureStore, never AsyncStorage), a single-retry-on-401
 * refresh, and zod-validated narrowing of the generated response types where
 * they under-describe the real payload (documented per field below).
 *
 * Calling convention: every generated `*Api` class method below takes a
 * single `requestParameters` object (e.g. `loginLocalUser({ loginLocalUserRequest: {...} })`,
 * `getData({ projectId, collectionId, documentId })`), NOT the positional
 * arguments shown in the SDK's docs/*.md examples — those examples are
 * generated from an older calling convention and no longer match the actual
 * `dist/api.js` class methods in the currently vendored SDK build. Calling
 * positionally throws a client-side `RequiredError` before any request
 * reaches the network (e.g. "Required parameter role was null or undefined"),
 * which is silent and easy to miss if you only read the docs and never
 * exercised the call against the live project — verified the hard way while
 * QAing this app end-to-end.
 */

export class MudbaseApiError extends Error {
  constructor(
    message: string,
    public readonly statusCode: number,
    public readonly code?: string,
  ) {
    super(message);
    this.name = "MudbaseApiError";
  }
}

export type RegisterOutcome =
  | { status: "authenticated"; user: MudbaseUser }
  | { status: "verification_required"; message: string };

interface PaginationMeta {
  page: number;
  limit: number;
  total: number;
  totalPages: number;
  hasMore: boolean;
}

interface ListDocumentsOptions {
  filter?: Record<string, unknown>;
  sort?: string;
  page?: number;
  limit?: number;
}

/**
 * The currently vendored SDK's generated `RegisterWithRole201Response` model
 * (dist/api.d.ts) is a real, filled-in shape — not `void` — and its request
 * model already includes `agreedToTerms` as a required field. This alias no
 * longer adds anything over `RegisterWithRoleRequest` itself; kept as a named
 * type (rather than inlined) only so a future SDK regeneration that narrows
 * or drops a field here fails at this one call site instead of silently
 * accepting a stale shape. The response is still parsed through
 * `authResultSchema` below rather than trusted as `res.data` directly, since
 * `mudbaseUserSchema`'s `customRole`/`isAnonymous` fields are project-session
 * fields this project-scoped register/login flow relies on beyond what any
 * single generated model documents.
 */
type RegisterWithRoleRequestBody = RegisterWithRoleRequest;

function toApiError(err: unknown): MudbaseApiError {
  if (isAxiosError(err)) {
    const status = err.response?.status ?? 0;
    const body = err.response?.data as { error?: string; message?: string; code?: string } | undefined;
    return new MudbaseApiError(body?.error ?? body?.message ?? err.message, status, body?.code);
  }
  if (err instanceof Error) return new MudbaseApiError(err.message, 0);
  return new MudbaseApiError("Unknown error", 0);
}

class MudbaseClient {
  private token: string | null = null;
  private refreshTokenValue: string | null = null;
  private refreshing: Promise<void> | null = null;

  private readonly configuration = new Configuration({
    basePath: MUDBASE_URL,
    accessToken: async (): Promise<string> => this.token ?? "",
  });

  private readonly authApi = new AuthenticationApi(this.configuration);
  private readonly multiRoleApi = new MultiRoleFeatureApi(this.configuration);
  private readonly dataApi = new DataApi(this.configuration);

  isAuthenticated(): boolean {
    return this.token !== null;
  }

  /** Loads any persisted tokens from SecureStore at app boot. Call once, before getSession(). */
  async restoreTokens(): Promise<boolean> {
    const [token, refreshTokenValue] = await Promise.all([
      secureStorage.get(STORAGE_KEYS.ACCESS_TOKEN),
      secureStorage.get(STORAGE_KEYS.REFRESH_TOKEN),
    ]);
    if (!token || !refreshTokenValue) return false;
    this.token = token;
    this.refreshTokenValue = refreshTokenValue;
    return true;
  }

  private async persistTokens(token: string, refreshTokenValue: string): Promise<void> {
    this.token = token;
    this.refreshTokenValue = refreshTokenValue;
    await Promise.all([
      secureStorage.set(STORAGE_KEYS.ACCESS_TOKEN, token),
      secureStorage.set(STORAGE_KEYS.REFRESH_TOKEN, refreshTokenValue),
    ]);
  }

  private async clearTokens(): Promise<void> {
    this.token = null;
    this.refreshTokenValue = null;
    await Promise.all([
      secureStorage.delete(STORAGE_KEYS.ACCESS_TOKEN),
      secureStorage.delete(STORAGE_KEYS.REFRESH_TOKEN),
    ]);
  }

  /**
   * Mudbase access tokens are short-lived (~30 min per AuthenticationApi.md's
   * "expiresIn" description). Refresh tokens rotate on every use and a reused
   * one revokes the session (platform reuse-detection) — so this in-flight
   * promise is shared across concurrent 401s to guarantee at most one refresh
   * call per expiry, never a stampede that would trip reuse-detection itself.
   */
  private async refreshSession(): Promise<void> {
    if (!this.refreshTokenValue) {
      throw new MudbaseApiError("No refresh token available — sign in again.", 401);
    }
    if (!this.refreshing) {
      this.refreshing = (async (): Promise<void> => {
        // The generated `AuthenticationApi` class (unlike the positional-args
        // shape shown in docs/AuthenticationApi.md) takes a single
        // requestParameters object wrapping the actual request body — see
        // `AuthenticationApiRefreshTokenRequest` in dist/api.d.ts. Every SDK
        // call in this file follows that same object-parameter convention;
        // calling positionally throws a client-side RequiredError before any
        // request reaches the network (verified against the live project).
        const res = await this.authApi.refreshToken({
          refreshTokenRequest: { refreshToken: this.refreshTokenValue as string },
        });
        const { token, refreshToken: nextRefreshToken } = res.data;
        if (!token || !nextRefreshToken) {
          throw new MudbaseApiError("Refresh response was missing new tokens.", 500);
        }
        await this.persistTokens(token, nextRefreshToken);
      })().finally(() => {
        this.refreshing = null;
      });
    }
    return this.refreshing;
  }

  private async withAuthRetry<T>(fn: () => Promise<AxiosResponse<T>>): Promise<T> {
    try {
      const res = await fn();
      return res.data;
    } catch (err) {
      if (isAxiosError(err) && err.response?.status === 401 && this.refreshTokenValue) {
        await this.refreshSession();
        const retried = await fn();
        return retried.data;
      }
      throw toApiError(err);
    }
  }

  // ─── Auth ────────────────────────────────────────────────────────────────

  async registerCustomer(input: {
    email: string;
    password: string;
    firstName: string;
    lastName: string;
  }): Promise<RegisterOutcome> {
    const body: RegisterWithRoleRequestBody = { ...input, projectId: MUDBASE_PROJECT_ID, agreedToTerms: true };
    try {
      // Self-signup is always the "customer" role — seller accounts are
      // provisioned once, out of band, with no self-service UI (see README
      // "Known limitations", mirroring web/README.md's own Provisioning note).
      const res = await this.multiRoleApi.registerWithRole({ role: "customer", registerWithRoleRequest: body });
      const parsed: AuthResult = authResultSchema.parse(res.data);
      if (parsed.token && parsed.refreshToken && parsed.user) {
        await this.persistTokens(parsed.token, parsed.refreshToken);
        return { status: "authenticated", user: parsed.user };
      }
      return {
        status: "verification_required",
        message: parsed.message ?? "Check your email to verify your account, then sign in.",
      };
    } catch (err) {
      throw toApiError(err);
    }
  }

  async login(email: string, password: string): Promise<MudbaseUser> {
    try {
      const res = await this.authApi.loginLocalUser({
        loginLocalUserRequest: { email, password, projectId: MUDBASE_PROJECT_ID },
      });
      const { token, refreshToken: refreshTokenValue } = res.data;
      if (!token || !refreshTokenValue) {
        throw new MudbaseApiError("Login response was missing tokens.", 500);
      }
      const user = mudbaseUserSchema.parse(res.data.user);
      await this.persistTokens(token, refreshTokenValue);
      return user;
    } catch (err) {
      if (err instanceof MudbaseApiError) throw err;
      if (isAxiosError(err) && err.response?.status === 403) {
        const body = err.response.data as { code?: string; error?: string } | undefined;
        if (body?.code === "EMAIL_VERIFICATION_REQUIRED") {
          throw new MudbaseApiError("Please verify your email before signing in.", 403, body.code);
        }
      }
      throw toApiError(err);
    }
  }

  async logout(): Promise<void> {
    try {
      await this.authApi.logoutLocalUser();
    } catch {
      // Best-effort server-side revoke — always clear local tokens regardless.
    } finally {
      await this.clearTokens();
    }
  }

  async getSession(): Promise<MudbaseUser | null> {
    if (!this.token) return null;
    try {
      const body = await this.withAuthRetry(() => this.authApi.getLocalSession({ projectId: MUDBASE_PROJECT_ID }));
      return mudbaseUserSchema.parse(body.user);
    } catch {
      await this.clearTokens();
      return null;
    }
  }

  // ─── Collections (Data API) ────────────────────────────────────────────

  async listDocuments<T>(
    schema: z.ZodType<T>,
    collectionId: string,
    options: ListDocumentsOptions = {},
  ): Promise<{ data: T[]; pagination: PaginationMeta }> {
    const filterStr =
      options.filter && Object.keys(options.filter).length > 0 ? JSON.stringify(options.filter) : undefined;
    const body = await this.withAuthRetry(() =>
      this.dataApi.listData({
        projectId: MUDBASE_PROJECT_ID,
        collectionId,
        page: options.page,
        limit: options.limit,
        sort: options.sort,
        filter: filterStr,
      }),
    );
    const list = z.array(schema).parse(body.data ?? []);
    const page = body.pagination?.page ?? 1;
    const totalPages = body.pagination?.totalPages ?? 1;
    return {
      data: list,
      pagination: {
        page,
        limit: body.pagination?.limit ?? list.length,
        total: body.pagination?.total ?? list.length,
        totalPages,
        hasMore: page < totalPages,
      },
    };
  }

  async getDocument<T>(schema: z.ZodType<T>, collectionId: string, documentId: string): Promise<T> {
    const body = await this.withAuthRetry(() =>
      this.dataApi.getData({ projectId: MUDBASE_PROJECT_ID, collectionId, documentId }),
    );
    return schema.parse(body.data);
  }

  async createDocument<T>(schema: z.ZodType<T>, collectionId: string, data: Record<string, unknown>): Promise<T> {
    const body = await this.withAuthRetry(() =>
      this.dataApi.createData({ projectId: MUDBASE_PROJECT_ID, collectionId, body: data }),
    );
    return schema.parse(body.data);
  }

  async updateDocument<T>(
    schema: z.ZodType<T>,
    collectionId: string,
    documentId: string,
    data: Record<string, unknown>,
  ): Promise<T> {
    const body = await this.withAuthRetry(() =>
      this.dataApi.updateData({ projectId: MUDBASE_PROJECT_ID, collectionId, documentId, body: data }),
    );
    return schema.parse(body.data);
  }

  async deleteDocument(collectionId: string, documentId: string): Promise<void> {
    await this.withAuthRetry(() =>
      this.dataApi.deleteData({ projectId: MUDBASE_PROJECT_ID, collectionId, documentId }),
    );
  }
}

export const mudbaseClient = new MudbaseClient();
