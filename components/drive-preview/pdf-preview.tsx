"use client";
export function PdfPreview({ url, name }: { url: string; name: string }) { return <iframe src={`${url}#toolbar=1&navpanes=0`} title={`PDF preview of ${name}`} className="h-full min-h-[65vh] w-full bg-white" />; }
