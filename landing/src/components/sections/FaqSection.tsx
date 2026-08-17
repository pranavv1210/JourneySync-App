import { faqs } from '@/data/site-content';
import { SectionHeading } from '@/components/ui/SectionHeading';
import { FAQAccordion } from '@/components/ui/FAQAccordion';

export function FaqSection() {
  return (
    <section id="faq" className="section-shell chapter-faq">
      <div className="container faq-container">
        <SectionHeading
          eyebrow="FAQ"
          title="Answers before you join the beta."
          align="center"
        />
        <FAQAccordion items={faqs} />
      </div>
    </section>
  );
}
