use anyhow::Result;
use chromiumoxide::browser::{Browser, BrowserConfig};
use futures::StreamExt;

#[tokio::main]
async fn main() -> Result<()> {
    // Get URL from command line args, default to a test page
    let url = std::env::args().nth(1).unwrap_or_else(|| {
        "https://example.com".to_string()
    });

    println!("Starting browser...");

    // Launch browser
    let (browser, mut handler) = Browser::launch(
        BrowserConfig::builder()
            .with_head() // Run with visible window for testing
            .build()
            .map_err(|e| anyhow::anyhow!("{}", e))?
    ).await?;

    // Spawn handler
    let handle = tokio::spawn(async move {
        while let Some(event) = handler.next().await {
            if let Err(e) = event {
                eprintln!("Browser event error: {:?}", e);
            }
        }
    });

    println!("Navigating to: {}", url);

    // Create new page and navigate
    let page = browser.new_page(&url).await?;

    // Wait for page to load
    page.wait_for_navigation().await?;

    // Get page title
    let title = page.get_title().await?.unwrap_or_default();
    println!("Page title: {}", title);

    // Get page content (for debugging)
    let content = page.content().await?;
    println!("Page content length: {} chars", content.len());

    // Keep browser open for a moment so we can see it
    println!("\nBrowser will close in 5 seconds...");
    tokio::time::sleep(tokio::time::Duration::from_secs(5)).await;

    // Cleanup
    drop(browser);
    handle.abort();

    println!("Done!");
    Ok(())
}
