import type { Database, Json } from '@/lib/database.types';

export type { Database, Json } from '@/lib/database.types';

export type PublicSchema = Database['public'];
export type TableName = keyof PublicSchema['Tables'];
export type ViewName = keyof PublicSchema['Views'];
export type RelationName = TableName | ViewName;
export type TableRow<TTable extends TableName> = PublicSchema['Tables'][TTable]['Row'];
export type ViewRow<TView extends ViewName> = PublicSchema['Views'][TView]['Row'];
export type RelationRow<TRelation extends RelationName> = TRelation extends TableName
  ? TableRow<TRelation>
  : TRelation extends ViewName
    ? ViewRow<TRelation>
    : never;
export type TableInsert<TTable extends TableName> = PublicSchema['Tables'][TTable]['Insert'];
export type TableUpdate<TTable extends TableName> = PublicSchema['Tables'][TTable]['Update'];

export interface SupabaseQueryError {
  message: string;
  code?: string;
  details?: string;
  hint?: string;
  table?: RelationName;
  operation: string;
}

export type SupabaseQueryResult<TData> =
  | { data: TData; error: null }
  | { data: null; error: SupabaseQueryError };
