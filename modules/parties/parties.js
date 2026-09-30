import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY } from "../auth/auth-config.js";

let supabase = null;

export function createPartiesApi() {
  if (!SUPABASE_PUBLISHABLE_KEY || SUPABASE_PUBLISHABLE_KEY.startsWith("REPLACE_")) {
    throw new Error("Supabase Publishable Key fehlt.");
  }

  supabase ??= createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY);

  return {
    listJoinableParties: () => supabase.rpc("get_joinable_parties"),
    getMyParty: () => supabase.rpc("get_my_party"),
    createParty: ({ name, tag }) => supabase.rpc("create_party", { p_name: name, p_tag: tag }),
    joinParty: (partyId) => supabase.rpc("join_party", { p_party_id: partyId }),
    leaveParty: (partyId) => supabase.rpc("leave_party", { p_party_id: partyId }),
    getMembers: (partyId) => supabase.rpc("get_party_members", { p_party_id: partyId }),
    changeRole: ({ partyId, memberId, role }) =>
      supabase.rpc("change_party_role", { p_party_id: partyId, p_member_id: memberId, p_role: role }),
    kickMember: ({ partyId, memberId }) =>
      supabase.rpc("kick_party_member", { p_party_id: partyId, p_member_id: memberId }),
    donate: ({ partyId, amount }) =>
      supabase.rpc("donate_to_party", { p_party_id: partyId, p_amount: amount }),
    getManagement: (partyId) => supabase.rpc("get_party_management", { p_party_id: partyId }),
    updateSettings: ({ partyId, name, tag, logoPath }) =>
      supabase.rpc("update_party_settings", {
        p_party_id: partyId, p_name: name, p_tag: tag, p_logo_path: logoPath
      }),
    purchaseUpgrade: ({ partyId, upgradeCode }) =>
      supabase.rpc("purchase_party_upgrade", {
        p_party_id: partyId, p_upgrade_code: upgradeCode
      })
  };
}
