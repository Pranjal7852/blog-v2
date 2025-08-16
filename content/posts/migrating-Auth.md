---
title: "Seamless Auth System Migration with Supertokens"
date: 2024-07-28
draft: false
---

![Auth System Migration with supertoken](/images/auth-supertokens.jpg)

Shortly after joining a Bangalore startup after college, due to my previous experience in working with auth systems, I was given the task to change the current auth system from admin-secret based to a token-based auth system. with our prod server having an active user base of 5000 plus users daily.

Adding more spice to the curry, since the app is used by children, we don’t want them to be redirected to a login screen after the new auth system is implemented. The transition for auth in both our frontend and backend systems should happen frictionlessly without users even noticing.

So, let’s begin on how we can achieve that.

I chose SuperTokens for this task as it takes care of a lot of things that, as a developer, I don’t have to make from scratch. SuperTokens has methods they call recipes, and I used the Passwordless phone method, which will require users to provide their phone number and, after OTP verification, will initiate a session.

This blog is not about how you can use SuperTokens; I am sure there are plenty of resources out there that teach you that. I am going to tell you a clever way to migrate your current auth system to a new one without users even noticing.

1. **Shortcut Way** - Migrate your user database to a new auth system. Yes, my friend, one might think this is the best way to do it. Many auth systems have an export user table feature, and you can just transfer it. Congratulations, you have shifted the user to a new auth system. But what if, during transfers, someone signs up on the platform? You are going to lose that. Also, for an organization with such a large user base and many new users coming every day, we don’t want the experience to be spoiled for anyone.

2. **Clever Way** - Consider two versions of your frontend client, A and B. Version A has the current auth system that you want to migrate, and version B has the new auth system set up by you. For simplicity's sake, let’s assume you have created a new auth system named C that handles sessions, tokens, post-sign-in, sign-up callbacks, etc.

   - **Step 1: Base Case** - Test out frontend B (the one with the new auth system) with backend C. Ideally, this will be the future of your application. The frontend has the new auth system, and the backend is configured with it. Test to ensure everything works. In my case, I replaced localStorage with a custom hook that sends session-related information to the frontend for any request made to our DB (Hasura).

   - **Step 2: Make an Endpoint** in your backend system C which will take user info, e.g., phone number or any unique identifier of your choice, and respond with an access token that can be stored in cookies of any system that calls it. It is just like a sign-up post route but without verification.

   ```jsx
   // generate token endpoint inside nodejs express app

   export const generatetoken = async (req, res) => {
     try {
       let phoneNumber = req.body.phoneNumber; // unique identifier in our case
       const input = {
         tenantId: `public`, // important for supertokens
         phoneNumber: phoneNumber,
       };

       let signupResponse = await signInUp(input); // sign-up function provided by supertokens

       if (signupResponse.status != "OK") {
         res.json("message: error in creating tokens");
       }
       const supertokenID = signupResponse.user.id; // user id created inside new auth system
       let session = await Session.createNewSessionWithoutRequestResponse(
         "public",
         supertokens.convertToRecipeUserId(supertokenID)
       );
       if (!session) {
         throw new Error("Session could not be created");
       }

       // Sending userInfo in the response as token
       res.json({ message: "Token generation done", sessionToken: session });
     } catch (error) {
       console.error("Error generating token:", error);
       res.status(500).send(error);
     }
   };
   ```

   - **Step 3: Integrate this Endpoint** into the current frontend with the old auth system ‘A’. In my case, I made a script using `useEffect` that makes a request to this endpoint I created when the app mounts. Note: This endpoint will only work for users who have already signed in to the application. We don’t want to generate tokens for every user using the application; otherwise, what kind of authentication system is it? :-)

   ```jsx
   // Script inside system where migration needs to be done, i.e., 'A'

   export const checkOrSetCookie = async () => {
     const user = localStorage.getItem("personalized_student"); // method to get unique identifier in old auth system

     if (user) {
       const { mobile: phoneNumber } = JSON.parse(user);
       if (phoneNumber) {
         try {
           const accessToken = await generateSessionToken(phoneNumber); // making request to above created endpoint
           if (!accessToken) {
             throw new Error("Failed to generate access token");
           }
           const userCookie = getCookie("personalized_student");
           if (userCookie) return;
           document.cookie = `personalized_student=${user}; domain=.yourDomain.com;`; // storing access token inside cookie
           document.cookie = `accesstoken=${accessToken}; domain=.yourDomain.com;`;
         } catch (error) {
           console.error("Error setting cookie:", error);
         }
       }
     }
   };
   ```

   - **Step 4: Run the Above Script** for 1 week in your existing system ‘A’ on production. By now, you have generated tokens for at least 99% of users using your app. Note: The tokens generated are stored inside the HTTP-only cookie of the user with an expiration time long enough before executing the next step.

   - **Step 5: Release Version B** of your frontend to production with an extra script to check for the token inside cookies. We call this script a migrate script. Also, you need to create an endpoint in the backend system which will accept tokens and initiate a session for the user making the request. If the token is found inside the cookies (which we did in Step 3), then do nothing. Congratulations, you have successfully migrated your user frictionlessly without them noticing anything. If not, then it might be a new user or the unlucky 1% who will be redirected to the sign-up page with the new auth system.

   ```jsx
   useEffect(() => {
     async function initializeSession() {
       // Ensure access token is set in the cookie

       function getCookie(name: string) {
         const value = `; ${document.cookie}`;
         const parts = value.split(`; ${name}=`);
         if (parts.length === 2) return parts?.pop()?.split(";")?.shift();
         return null;
       }

       // Attempt to refresh session
       const accessToken = getCookie("accesstoken");
       if (accessToken) {
         try {
           const response = await axios.post(
             `${process.env.NEXT_PUBLIC_SUPERTOKEN_API_BACKEND_DOMAIN}/supertoken/migrate`,
             {},
             {
               headers: {
                 Authorization: `Bearer ${accessToken}`,
               },
             }
           );
           if (response.data.status != "OK") {
             throw new Error("No Supertoken session started");
           }
           console.log("Supertoken session established", response);
         } catch (err) {
           console.error("Error refreshing session", err);
         }
       } else {
         window.redirect("/signup"); // this is optional as you may have your own route protection
       }
     }

     initializeSession();
   }, []);
   ```
