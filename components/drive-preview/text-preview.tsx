"use client";
import { useEffect, useState } from "react";
import { Loader2 } from "lucide-react";
export function TextPreview({ blob }: { blob: Blob }) { const [text, setText] = useState<string | null>(null); useEffect(() => { let active = true; void blob.text().then((value) => { if (active) setText(value.slice(0, 2_000_000)); }); return () => { active = false; }; }, [blob]); return text === null ? <Loader2 className="h-6 w-6 animate-spin" /> : <pre className="h-full min-h-[65vh] w-full overflow-auto whitespace-pre-wrap break-words bg-slate-950 p-4 text-xs text-slate-100">{text}</pre>; }
