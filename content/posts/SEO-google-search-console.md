+++
title = 'How to Ensure Your Websites Ranks on Google'
date = 2024-12-28T15:33:44+05:30
draft = false
+++

# Custom solutions to enhance Search Enginer Optimization and an Overview of Google Seach Console

Imagine this: Your web app is ready to rock the world. You’ve nailed the development, deployment is flawless, and your marketing team is prepped to take the spotlight. But there’s a catch—when users Google your app’s name, your website doesn’t show up. How can users trust your app is legit? And if they want to test your product, how will they find it? You can’t just hand out your server’s IP address to bypass DNS, right?

![Google Seach Console Dashboard](/images/GSC-dashboard.png)

Let’s dive into this problem and explore how I helped our site rank at the top of Google’s search results.

## What is Indexing, and Why Does It Matter?

Before we dive into solutions, let’s address the basics. **What is indexing?**  
Indexing is the process by which search engine bots (also known as crawlers) store your site’s content—like text, images, and metadata—in their database. This allows Google to quickly retrieve and display relevant results when users search for something.

But what if your site isn’t being indexed properly? That’s where **Google Search Console (GSC)** and a few SEO best practices come into play.

## Problem 1: Canonical URLs for Multi-Region Websites

If your website has multiple versions—say, one for the US (`example.us`), one for Japan (`example.jp`), and another for India (`example.in`)—you need to ensure users see the correct version based on their location. You don’t want a user in the US landing on the Japanese version of your site, do you?

### Solution: Dynamically Generate Sitemaps and Robots.txt Files

To tackle this, we implemented a dynamic sitemap and `robots.txt` generation system. Here’s how it works:

1.  **Environment-Based Sitemap Generation**:  
    We used environment variables (e.g., `REGION=jp`) to generate sitemaps tailored to each region. For example, if `REGION=jp`, the sitemap would prioritize `https://example.jp` as the canonical URL.

![Dynamic Sitemap](/images/dynamic-sitemap.png)

2.  **Dynamic URLs for Content**:  
    We also fetched data from the server to dynamically include all relevant pages in the sitemap. This ensures every page is indexed without manual intervention.

Here’s an example of how we implemented this in Next.js:

```
function generateSiteMap(worksheets) {
  return `<?xml version="1.0" encoding="UTF-8"?>
  <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    <!-- Static URLs -->
    <url>
      <loc>https://example.${process.env.REGION}</loc>
      <changefreq>weekly</changefreq>
      <priority>1.0</priority>
    </url>
    <url>
      <loc>https://example.ai/home</loc>
      <changefreq>daily</changefreq>
      <priority>0.8</priority>
    </url>
    <url>
      <loc>https://example.ai/onboarding</loc>
      <changefreq>weekly</changefreq>
      <priority>0.7</priority>
    </url>
    <!-- Dynamic URLs from worksheet data --> ${worksheets
      .map(({ worksheet_id, activity_id }) => {
        return ` <url>
          <loc>${`https://example.ai/home/worksheet/${worksheet_id}/${activity_id}`}</loc>
          <changefreq>monthly</changefreq>
          <priority>0.6</priority>
        </url> `;
      })
      .join("")}
  </urlset>`;
}
```

### Additional Methods to Set Canonical URLs

1.  Add a `rel=canonical` link to your HTML file.
2.  Send an HTML header with `rel=canonical`.
3.  Include `rel=canonical` in your sitemap for all builds.
4.

## Problem 2: Preventing Test or Beta Sites from Being Indexed

You don’t want your testing or beta versions popping up on Google, right? These versions aren’t meant for end users, and indexing them can lead to confusion.

### Solution: Use Robots.txt to Disallow Crawling

By adding test or beta site URLs to your `robots.txt` file, you can instruct search engine bots to skip these pages. Here’s an example:

```
# Allow all search engines to crawl the entire site
User-agent: *
Disallow: /api.us.example.ai/
Disallow: /graphql.us.example.ai/
Disallow: /home/worksheet/
Disallow: /proxy.mixpanel.example.ai/

# Allow Googlebot to access the entire site
User-agent: Googlebot
Disallow:

# Allow Bingbot to access the entire site
User-agent: Bingbot
Disallow:

# Sitemap location
Sitemap: http://www.exmaple.ai/sitemap.xml
```

## How Google Search Console (GSC) Can Help

Google Search Console is a powerful tool for developers and marketers alike. It helps you monitor and troubleshoot your site’s presence in Google Search results. Here’s how to get started:

1.  **Register Your Domain**:  
    Add your website to GSC and verify ownership.
2.  **Identify Issues**:  
    GSC will highlight any indexing or crawling issues.
3.  **Fix and Optimize**:  
    Address the issues to ensure your site is properly indexed.

## Final Thoughts

Ensuring your web app ranks on Google isn’t just about great content—it’s about technical SEO too. By setting the right canonical URLs, dynamically generating sitemaps, and leveraging tools like Google Search Console, you can significantly improve your site’s visibility.
