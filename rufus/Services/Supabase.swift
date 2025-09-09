import Foundation
import Supabase

// Supabase configuration: prefer environment variables (useful for Xcode schemes, CI),
// otherwise fall back to Keychain storage under "supabaseKey".
let supabaseURLString = ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? "https://vmzmwybvcybsiplmmelv.supabase.co"
let supabaseKeyFromEnv = ProcessInfo.processInfo.environment["SUPABASE_KEY"]
let supabaseKey = supabaseKeyFromEnv ?? KeychainHelper.shared.read(key: "supabaseKey") ?? ""

let supabase = SupabaseClient(
  supabaseURL: URL(string: supabaseURLString)!,
  supabaseKey: supabaseKey
)
