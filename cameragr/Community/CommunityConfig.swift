import Foundation

/// Where Koco's community lives (Supabase project koco-community, Tokyo).
/// Both values are public by design: the publishable key only reaches what
/// the database's row-level security allows a signed-in or anonymous user.
/// The project's secret keys are never in the app.
enum CommunityConfig {
    static let url = URL(string: "https://kgccuqrrfqgytukzpffj.supabase.co")!
    static let publishableKey = "sb_publishable_HDZsr0jz8JtYsfJBpabmvg_kES9ZnUv"
}
