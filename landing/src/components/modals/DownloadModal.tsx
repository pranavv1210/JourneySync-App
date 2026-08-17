'use client';

import { AppModal } from './AppModal';

export function DownloadModal({
  isOpen,
  onClose,
}: {
  isOpen: boolean;
  onClose: () => void;
}) {
  return (
    <AppModal
      isOpen={isOpen}
      onClose={onClose}
      title="Download Android beta"
      labelledBy="download-modal-title"
      size="md"
      panelClassName="border-white/15 bg-[#171717] text-white"
      headerClassName="bg-[#171717]/95 text-white border-white/10"
      contentClassName="text-white"
    >
      <div className="download-modal-body">
        <p className="eyebrow light">Closed beta</p>
        <p>
          This is an early rider test build for active groups. Install it only if you are
          comfortable testing beta software and sharing feedback.
        </p>

        <ul className="download-modal-list">
          <li>
            <span className="material-icons-round">android</span>
            Android beta APK is available now.
          </li>
          <li>
            <span className="material-icons-round">verified_user</span>
            Ride carefully and do not interact with the app while moving.
          </li>
          <li>
            <span className="material-icons-round">feedback</span>
            Feedback from Bengaluru rider groups will shape the next build.
          </li>
        </ul>

        <div className="download-modal-actions">
          <a href="/journeysync.apk" download className="download-modal-primary">
            <span className="material-icons-round">download</span>
            Download Android beta
          </a>
          <a
            href="mailto:journeysync.app@gmail.com?subject=JourneySync%20closed%20beta%20access"
            className="download-modal-secondary"
          >
            <span className="material-icons-round">mail</span>
            Request beta access
          </a>
        </div>
      </div>
    </AppModal>
  );
}
