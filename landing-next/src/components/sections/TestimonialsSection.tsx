import { testimonials } from '@/data/site-content';
import { SectionHeading } from '@/components/ui/SectionHeading';
import { TestimonialCarousel } from '@/components/ui/TestimonialCarousel';

export function TestimonialsSection() {
  return (
    <section id="testimonials" className="section-shell chapter-testimonials">
      <div className="container">
        <SectionHeading
          eyebrow="Rider feedback"
          title="What founding riders are asking for."
          description="Short beta signals from Bengaluru riders who understand the group-ride problem."
          align="center"
        />
        <TestimonialCarousel items={testimonials} />
      </div>
    </section>
  );
}
