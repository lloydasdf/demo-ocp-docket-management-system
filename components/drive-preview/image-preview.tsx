"use client";
export function ImagePreview({ url, name }: { url: string; name: string }) { return <img src={url} alt={name} className="max-h-full max-w-full object-contain" />; }
