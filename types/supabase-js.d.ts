declare module '@supabase/supabase-js' {
  type PublicTables<TDatabase> = TDatabase extends { public: { Tables: infer TTables } } ? TTables : never;
  type PublicViews<TDatabase> = TDatabase extends { public: { Views: infer TViews } } ? TViews : never;
  type PublicRelations<TDatabase> = PublicTables<TDatabase> & PublicViews<TDatabase>;
  type RelationName<TDatabase> = Extract<keyof PublicRelations<TDatabase>, string>;
  type RowFor<TDatabase, TName extends RelationName<TDatabase>> = PublicRelations<TDatabase>[TName] extends {
    Row: infer TRow;
  }
    ? TRow
    : never;

  export type SupabaseQueryResponse<TData> = {
    data: TData | null;
    error: unknown;
  };

  export type SupabaseQueryBuilder<TData> = PromiseLike<SupabaseQueryResponse<TData>> & {
    select<TSelected = TData>(columns?: string, options?: unknown): SupabaseQueryBuilder<TSelected>;
    order(column: string, options?: { ascending?: boolean; nullsFirst?: boolean; foreignTable?: string }): SupabaseQueryBuilder<TData>;
    limit(count: number, options?: { foreignTable?: string }): SupabaseQueryBuilder<TData>;
    eq(column: string, value: unknown): SupabaseQueryBuilder<TData>;
    or(filters: string, options?: { foreignTable?: string }): SupabaseQueryBuilder<TData>;
    single(): Promise<SupabaseQueryResponse<TData extends Array<infer TRow> ? TRow : TData>>;
  };

  export type SupabaseClient<TDatabase = unknown> = {
    from<TName extends RelationName<TDatabase>>(table: TName): SupabaseQueryBuilder<RowFor<TDatabase, TName>[]>;
  };

  export function createClient<TDatabase = unknown>(
    supabaseUrl: string,
    supabaseKey: string,
    options?: unknown,
  ): SupabaseClient<TDatabase>;
}
