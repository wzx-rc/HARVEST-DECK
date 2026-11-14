import type { PortalConfig } from "@harvest-deck/kit";

export const PORTAL_CONFIG: PortalConfig = {
  portalId: import.meta.env.VITE_PORTAL_ID ?? "portal-template",
  apiUrl: import.meta.env.VITE_API_URL,
  gameUrl: import.meta.env.VITE_PORTAL_GAME_URL,
};
