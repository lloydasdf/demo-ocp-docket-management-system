"use client";
import { ShieldAlert } from "lucide-react";
import type { PreviewFile } from "./types";
export function UnsupportedPreview({ file, executable }: { file: PreviewFile; executable: boolean }) { return <div className="max-w-md text-center"><ShieldAlert className="mx-auto mb-3 h-12 w-12 text-muted-foreground" /><p className="font-medium">{executable ? "Executable preview blocked" : "Preview not available"}</p><p className="mt-1 text-sm text-muted-foreground">{executable ? "For safety, executable files are never rendered or run in the browser." : `This file type (${file.mimeType || "unknown"}) does not have an in-browser renderer.`}</p></div>; }
