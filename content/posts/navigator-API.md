+++
title = 'Know your user like never before using Navigator API'
date = 2024-08-08T14:53:12+05:30
draft = false
+++

# Navigator API - More than meets the Eye

![Navigator API present inside Chrome Dev](/images/chrome_dev.png)

For those who don’t know, the Navigator API is a native API available in all browsers that provides user-centric metrics for your website. It offers insights into how your high-value site is performing. Some may use it to customize the interface for different platforms, such as displaying premium items to iOS users, but its main purpose is to understand how your code behaves across different user environments and internet speeds, including ping. This helps developers diagnose and recreate issues to solve them more effectively. The Navigator API also provides CPU heap statistics, which reveal how CSS effects impact users' CPU threads.

By now, you might have a better understanding of what the Navigator API is and why it’s valuable. Let’s see how to incorporate it into your million dollar web app.

---

For practical use—specifically the task I was assigned—we use Sentry for our app, which does an excellent job tracking errors. However, knowing about an error is only part of the story; additional information is crucial for effective troubleshooting. Key statistics like network speed at the time of the error, heap size, or RAM usage on the device are needed.

Let’s address the key aspects one by one:

1. **Environment/Model - `navigator.userAgent`**

This is the most crucial information. It reveals details about the operating system on which the web page is being viewed, as well as key information about the manufacturer, platform, and web view version.

```jsx
const userAgent = navigator.userAgent;
console.log(userAgent);

//console output
//      {
//         "isVirtual": false,
//         "manufacturer": "Google Inc.",
//         "model": "Macintosh",
//         "operatingSystem": "mac",
//         "osVersion": "10.15.7",
//         "platform": "web",
//         "webViewVersion": "127.0.0.0"
//       },
```

1. CPU heap Size - ``

The memory heap is the portion of memory allocated to the JavaScript runtime to store all objects, strings, and data structures. In simple terms, the more memory allocated, the more processing power your processor will need to handle the calculations and data management.

```jsx
const userCPUHeap = performance.memory;
console.log(userCPUHeap);

//console output
//  {
//         "totalJSHeapSize": 124342323 Bytes,
//         "totalJSHeapSize": 66605138 Bytes,
//         "usedJSHeapSize": 51178854 Bytes,
//   },
```

1. RAM

This gives the at-least physical hardware RAM memory in GB of the user machine. Unlike JS heap size it value is is in range [2,3,4,8]. For devices greater than 8 this method with return 8 .

```jsx
const userPhysicalRAM = navigator.deviceMemory;
console.log(userPhysicalRAM);

//console output
//  {
//  RAM: 8
//  }
```

1. Network Stats

If you want to measure the user's network speed while loading your website, this is a key statistic for tracking and monitoring your web vitals based on the user's average network speed. While one method is to download a test file of known size and measure the time taken for the operation, this approach can increase the app size and waste user resources.

```jsx
const networkInfo =
  "connection" in navigator
    ? navigator.connection ||
      navigator.mozConnection ||
      navigator.webkitConnection
    : null;

const userNetworkInfo = {
  effectiveType: networkInfo ? networkInfo.effectiveType : "Not available",
  downlink: networkInfo ? networkInfo.downlink : "Not available",
  rtt: networkInfo ? networkInfo.rtt : "Not available",
};

console.log(userNetworkInfo);

// Example console output
// {
//   effectiveType: '4g', Network Type of user Wifi or Band
//   downlink: 10, This is the avg Speed calculated by Chrome
//   rtt: 50
// }
```

The `downlink` field provides the approximate bandwidth of the client's connection to the server, measured in Mbps, while the `RTT` field estimates the round-trip time in milliseconds (ms) for the network.

For practical purposes, these metrics are essential for tracking user performance. Remember to append this data to your Mixpanel events for comprehensive data analytics which we did in our systems.

**Alert 🍎 (For Apple enthusiasts):** Due to privacy constraints, some API endpoints are not supported by Safari. This means you won’t be able to obtain certain information, such as network speed, RAM, or CPU heap size, as of now. Good luck with that! 😊
