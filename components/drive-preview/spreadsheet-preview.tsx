"use client";
import { useEffect, useMemo, useState } from "react";
import { Loader2, Search } from "lucide-react";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";

type Sheet = { name: string; rows: string[][] };
export function SpreadsheetPreview({ blob, isCsv }: { blob: Blob; isCsv: boolean }) {
  const [sheets, setSheets] = useState<Sheet[]>([]); const [active, setActive] = useState(0); const [search, setSearch] = useState(""); const [error, setError] = useState<string | null>(null);
  useEffect(() => { let mounted = true; (async () => { try { if (isCsv) { const text = await blob.text(); const rows = text.split(/\r?\n/).slice(0, 5000).map((line) => line.split(",")); if (mounted) setSheets([{ name: "CSV", rows }]); return; } const ExcelJS = await import("exceljs"); const workbook = new ExcelJS.Workbook(); await workbook.xlsx.load(await blob.arrayBuffer()); const parsed: Sheet[] = []; workbook.eachSheet((sheet) => { const rows: string[][] = []; sheet.eachRow({ includeEmpty: true }, (row) => rows.push((row.values as unknown[]).slice(1).map((value) => String(value ?? "")))); parsed.push({ name: sheet.name, rows: rows.slice(0, 5000) }); }); if (mounted) setSheets(parsed); } catch (cause) { if (mounted) setError(cause instanceof Error ? cause.message : "Unable to render spreadsheet."); } })(); return () => { mounted = false; }; }, [blob, isCsv]);
  const rows = useMemo(() => (sheets[active]?.rows ?? []).filter((row) => !search || row.some((cell) => cell.toLowerCase().includes(search.toLowerCase()))), [sheets, active, search]);
  if (error) return <p className="p-6 text-sm text-destructive">{error}</p>; if (!sheets.length) return <Loader2 className="h-6 w-6 animate-spin" />;
  return <div className="flex h-full min-h-[65vh] w-full flex-col bg-background"><div className="flex flex-wrap items-center gap-2 border-b p-2">{sheets.map((sheet, index) => <Button key={sheet.name} size="sm" variant={active === index ? "default" : "outline"} onClick={() => setActive(index)}>{sheet.name}</Button>)}<div className="relative ml-auto"><Search className="absolute left-2 top-2.5 h-4 w-4 text-muted-foreground" /><Input value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Search sheet" className="pl-8" /></div></div><div className="flex-1 overflow-auto"><table className="border-collapse text-xs"><tbody>{rows.map((row, rowIndex) => <tr key={rowIndex}>{row.map((cell, cellIndex) => <td key={cellIndex} className="max-w-72 border px-2 py-1 align-top">{cell}</td>)}</tr>)}</tbody></table></div></div>;
}
