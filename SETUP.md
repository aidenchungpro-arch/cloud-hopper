# Cloud Hopper: turning on the global leaderboard (5 minutes, free)

The game works without this. Until you do it, the leaderboard screen says "not set up".

1. Go to https://console.firebase.google.com and click **Add project** (name it anything, you can skip Google Analytics).
2. In the left menu choose **Build > Realtime Database > Create Database**. Pick any location and start in **locked mode**.
3. Open the **Rules** tab, delete what is there, paste the contents of `database.rules.json` from this folder, and click **Publish**.
4. Open the **Data** tab. Copy the database URL shown at the top. It looks like
   `https://your-project-default-rtdb.firebaseio.com`
5. Open `main.gd` and paste it between the quotes on this line near the top:
   `const FIREBASE_URL := ""`
6. Run the game. Play, set a name, die, and your score appears on the trophy screen.

## How it works
- Each player gets a random id stored on their device. Their best score is saved at `scores/<id>`.
- The rules only allow a score to be replaced by a **higher** one, so scores can't be lowered or deleted.
- The board shows the top 10 and highlights your own row.
- If the player is offline when they set a record, it is retried after their next run.

## Good to know
- No server code is needed. The game talks to Firebase's REST API directly.
- Because the game runs on the player's device, a determined cheater could post a fake score.
  The rules cap scores at 1,000,000 and limit names to 12 characters. Stronger protection needs a server
  that checks runs, which is out of scope here.
- Exporting to the web works. Firebase allows browser requests.
