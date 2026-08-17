import { comparisonRows } from '@/data/site-content';
import { SectionHeading } from '@/components/ui/SectionHeading';

export function ComparisonSection() {
  return (
    <section id="comparison" className="section-shell chapter-light">
      <div className="container">
        <SectionHeading
          eyebrow="Why JourneySync"
          title="Maps navigate. Chats notify. JourneySync coordinates the ride."
          description="Riders already use Google Maps and WhatsApp. JourneySync is the missing ride layer that connects navigation, safety, and group state."
        />

        <div className="comparison-desktop" role="region" aria-label="JourneySync comparison table">
          <table className="comparison-table">
            <thead>
              <tr>
                <th scope="col">Capability</th>
                <th scope="col">Google Maps</th>
                <th scope="col">WhatsApp</th>
                <th scope="col">JourneySync</th>
              </tr>
            </thead>
            <tbody>
              {comparisonRows.map((row) => (
                <tr key={row.category}>
                  <th scope="row">{row.category}</th>
                  <td>{row.googleMaps}</td>
                  <td>{row.whatsapp}</td>
                  <td className="highlight">{row.journeysync}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        <div className="comparison-mobile">
          {comparisonRows.map((row) => (
            <article key={row.category} className="comparison-card">
              <h3>{row.category}</h3>
              <div className="comparison-card-grid">
                <div>
                  <span>Google Maps</span>
                  <p>{row.googleMaps}</p>
                </div>
                <div>
                  <span>WhatsApp</span>
                  <p>{row.whatsapp}</p>
                </div>
                <div className="highlight">
                  <span>JourneySync</span>
                  <p>{row.journeysync}</p>
                </div>
              </div>
            </article>
          ))}
        </div>
      </div>
    </section>
  );
}
