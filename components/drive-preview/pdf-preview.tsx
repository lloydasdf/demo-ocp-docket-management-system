"use client";

import { Download, ExternalLink, FileText, Share2, X } from "lucide-react";
import { Button } from "@/components/ui/button";

export function PdfPreview({ url, name, narrow, onShare, onDownload, onClose }: { url: string; name: string; narrow: boolean; onShare: () => void; onDownload: () => void; onClose: () => void }) {
  if (!narrow) return <iframe src={`${url}#toolbar=1&navpanes=0`} title={`PDF preview of ${name}`} className="h-full min-h-[65vh] w-full bg-white" />;

  return <div className="flex h-full min-h-[65vh] w-full items-center justify-center bg-background p-6">
    <div className="w-full max-w-sm text-center"><FileText className="mx-auto h-16 w-16 text-red-600" /><h2 className="mt-4 truncate text-lg font-semibold">{name}</h2><p className="mt-2 text-sm text-muted-foreground">Open this PDF in your device&apos;s native viewer.</p>
      <div className="mt-6 grid gap-3"><Button asChild size="lg"><a href={url} target="_blank" rel="noopener noreferrer"><ExternalLink className="mr-2 h-4 w-4" />Open PDF</a></Button><Button variant="outline" onClick={onShare}><Share2 className="mr-2 h-4 w-4" />Share</Button><Button variant="outline" onClick={onDownload}><Download className="mr-2 h-4 w-4" />Download</Button><Button variant="ghost" onClick={onClose}><X className="mr-2 h-4 w-4" />Close</Button></div>
    </div>
  </div>;
}
