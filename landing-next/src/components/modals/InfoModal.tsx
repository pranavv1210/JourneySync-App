'use client';

import { useEffect, useMemo, useState } from 'react';
import { Briefcase, FileText, Info, Mail, Newspaper, Shield } from 'lucide-react';
import type { LucideIcon } from 'lucide-react';
import { AppModal } from './AppModal';
import { infoContent } from '@/data/info-content';
import { extractPreText, isDocumentHeading } from '@/lib/legal';

type InfoKey = keyof typeof infoContent;

const iconMap: Record<InfoKey, LucideIcon> = {
  about: Info,
  careers: Briefcase,
  blog: Newspaper,
  contact: Mail,
  privacy: Shield,
  terms: FileText,
  safety: Shield,
} as const;

function renderBodyItem(item: string | { prefix?: string; label: string; href: string; external?: boolean }) {
  if (typeof item === 'string') return item;

  return (
    <>
      {item.prefix ?? ''}
      <a
        href={item.href}
        target={item.external ? '_blank' : undefined}
        rel={item.external ? 'noopener noreferrer' : undefined}
      >
        {item.label}
      </a>
    </>
  );
}

function DocumentText({ text }: { text: string }) {
  return (
    <div className="app-modal-document">
      {text.split(/\n+/).map((line) => {
        const value = line.trim();
        if (!value) return null;
        if (isDocumentHeading(value)) {
          return <h3 key={value}>{value}</h3>;
        }
        return <p key={value}>{value}</p>;
      })}
    </div>
  );
}

export function InfoModal({
  modalKey,
  onClose,
}: {
  modalKey: string | null;
  onClose: () => void;
}) {
  const key = (modalKey && modalKey in infoContent ? modalKey : '') as InfoKey | '';
  const content = key ? infoContent[key] : null;
  const Icon = key ? iconMap[key] : Info;
  const [privacyText, setPrivacyText] = useState<string>('');
  const [privacyLoading, setPrivacyLoading] = useState(false);
  const [termsText, setTermsText] = useState<string>('');
  const [termsLoading, setTermsLoading] = useState(false);

  useEffect(() => {
    if ((key !== 'privacy' && key !== 'terms') || !modalKey) return;

    let cancelled = false;
    const loadDocument = async () => {
      if (key === 'privacy') setPrivacyLoading(true);
      if (key === 'terms') setTermsLoading(true);
      try {
        const response = await fetch(
          key === 'privacy' ? '/privacy-policy.html' : '/terms-of-use.txt',
          { cache: 'force-cache' },
        );
        const text = await response.text();
        if (!cancelled && key === 'privacy') setPrivacyText(extractPreText(text));
        if (!cancelled && key === 'terms') setTermsText(text.trim());
      } catch {
        if (!cancelled) {
          const fallback = `Could not load the ${key === 'privacy' ? 'privacy policy' : 'terms of use'}. Please contact journeysync.app@gmail.com.`;
          if (key === 'privacy') setPrivacyText(fallback);
          if (key === 'terms') setTermsText(fallback);
        }
      } finally {
        if (!cancelled && key === 'privacy') setPrivacyLoading(false);
        if (!cancelled && key === 'terms') setTermsLoading(false);
      }
    };

    void loadDocument();
    return () => {
      cancelled = true;
    };
  }, [key, modalKey]);

  const docText = useMemo(() => {
    if (!content) return '';
    if (key === 'privacy') return privacyText;
    if (key === 'terms') return termsText;
    return content.documentText ?? '';
  }, [content, key, privacyText, termsText]);

  const isDocument = Boolean(docText);

  return (
    <AppModal
      isOpen={Boolean(content)}
      onClose={onClose}
      title={content?.title}
      icon={Icon}
      labelledBy="info-modal-title"
      size="lg"
      maxWidth={isDocument ? '56rem' : '50rem'}
      contentClassName={isDocument ? 'app-modal-document-scroll' : ''}
      panelClassName="border-white/62 bg-[linear-gradient(145deg,rgba(255,255,255,0.97),rgba(255,249,244,0.93))] text-neutral-900"
      headerClassName="bg-white/92 text-neutral-950"
    >
      {(privacyLoading && key === 'privacy') || (termsLoading && key === 'terms') ? (
        <div className="py-8 text-center text-sm text-neutral-600">Loading document...</div>
      ) : isDocument ? (
        <DocumentText text={docText} />
      ) : content?.sections ? (
        <div className="app-modal-content mx-auto max-w-[680px]">
          {content.sections.map((section) => (
            <section className="app-modal-section" key={section.heading}>
              <h3>{section.heading}</h3>
              {section.body?.map((paragraph) => (
                <p key={typeof paragraph === 'string' ? paragraph : paragraph.label}>
                  {renderBodyItem(paragraph)}
                </p>
              ))}
              {section.list && (
                <ul>
                  {section.list.map((item) => (
                    <li key={item}>{item}</li>
                  ))}
                </ul>
              )}
            </section>
          ))}
        </div>
      ) : null}
    </AppModal>
  );
}
