declare module "docx-preview" {
  export type Options = {
    breakPages?: boolean;
    ignoreFonts?: boolean;
    ignoreHeight?: boolean;
    ignoreWidth?: boolean;
    renderFooters?: boolean;
    renderHeaders?: boolean;
    renderEndnotes?: boolean;
    renderFootnotes?: boolean;
    useBase64URL?: boolean;
  };

  export function renderAsync(
    data: Blob | ArrayBuffer | Uint8Array,
    bodyContainer: HTMLElement,
    styleContainer?: HTMLElement,
    options?: Options,
  ): Promise<void>;
}
