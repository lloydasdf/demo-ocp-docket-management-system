"use client";

import { useEffect, useId, useState } from "react";
import { Loader2 } from "lucide-react";

declare global { interface Window { DocsAPI?: { DocEditor: new (id: string, config: Record<string, unknown>) => { destroyEditor: () => void } } } }
export type OnlyOfficeSession = { sessionId: string; serverUrl: string; config: Record<string, unknown> };

export function OnlyOfficeEditor({ session, checkStatus, cancelSession, onSaved, onError }: { session: OnlyOfficeSession; checkStatus: (sessionId: string) => Promise<{ status: string; last_error?: string | null }>; cancelSession: (sessionId: string) => Promise<void>; onSaved: () => void; onError: (message: string) => void }) {
  const reactId = useId(); const containerId = `onlyoffice-${reactId.replace(/:/g, '')}`; const [loading, setLoading] = useState(true);
  useEffect(() => {
    let editor: { destroyEditor: () => void } | undefined; let cancelled = false;
    const launch = () => { if (cancelled || !window.DocsAPI) return; editor = new window.DocsAPI.DocEditor(containerId, { ...session.config, events: { onDocumentReady: () => setLoading(false), onError: (event: { data?: { errorDescription?: string } }) => onError(event.data?.errorDescription ?? "The document editor reported an error.") } }); };
    const existing = document.querySelector<HTMLScriptElement>('script[data-onlyoffice-api]');
    if (existing) { if (window.DocsAPI) launch(); else existing.addEventListener('load', launch, { once: true }); }
    else { const script = document.createElement('script'); script.src = `${session.serverUrl}/web-apps/apps/api/documents/api.js`; script.dataset.onlyofficeApi = 'true'; script.onload = launch; script.onerror = () => { void cancelSession(session.sessionId); onError('ONLYOFFICE Document Server is unavailable.'); }; document.head.appendChild(script); }
    return () => { cancelled = true; editor?.destroyEditor(); };
  }, [cancelSession, containerId, onError, session]);
  useEffect(() => { const timer = window.setInterval(() => { void checkStatus(session.sessionId).then((result) => { if (result.status === 'SAVED') onSaved(); else if (result.status === 'FAILED') onError(result.last_error || 'Document save failed.'); }).catch(() => undefined); }, 2000); return () => window.clearInterval(timer); }, [checkStatus, onError, onSaved, session.sessionId]);
  return <div className="relative h-full min-h-[72vh] w-full bg-background">{loading ? <div className="absolute inset-0 z-10 flex items-center justify-center bg-background"><Loader2 className="mr-2 h-5 w-5 animate-spin" />Launching document editor…</div> : null}<div id={containerId} className="h-full min-h-[72vh] w-full" /></div>;
}
