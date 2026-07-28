"use client";
export function MediaPreview({ url, mimeType }: { url: string; mimeType: string }) { return mimeType.startsWith("video/") ? <video src={url} controls className="max-h-full max-w-full" /> : <audio src={url} controls className="w-full max-w-xl" />; }
