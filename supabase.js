
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = "https://jtvimhichjjbwmagugsf.supabase.co";

const supabaseKey = "sb_publishable_3fYzFZLvMavPqExGf_4OAg_83fNCIWM";

export const supabase = createClient(supabaseUrl, supabaseKey);
