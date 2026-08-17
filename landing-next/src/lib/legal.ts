export function extractPreText(html: string): string {
  const match = html.match(/<pre[^>]*>([\s\S]*?)<\/pre>/i);
  const raw = match ? match[1] : html;

  if (typeof window === 'undefined') {
    return raw
      .replaceAll('&quot;', '"')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .trim();
  }

  const textarea = document.createElement('textarea');
  textarea.innerHTML = raw;
  return textarea.value.trim();
}

export function isDocumentHeading(line: string): boolean {
  return /^[0-9]+\. [A-Z0-9 ,?'-]+$/.test(line) || /^[A-Z][A-Z0-9 ,?'-]{5,}$/.test(line);
}
