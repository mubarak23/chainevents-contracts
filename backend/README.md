# HOW TO SETUP

### STEP 1
> Clone this repository to your machine

### STEP 2
> Run `npm install` to install all dependencies

### STEP 3
> Copy `.env.example` to `.env` file and update the postgresql credentials for production environment also set NODE_ENV to production if you want to run production, you can either use DB URL or set DB host,username,password and port with SSL for your DB connection.

### STEP 4
> Get your Apibara DNA Token:
> 1. Create an account at [Apibara](https://www.apibara.com/)
> 2. Click on "New Indexer" to create an indexer
> 3. Copy the DNA token provided
> 4. Paste the token in your `.env` file as `DNA_TOKEN`

### STEP 5
> Start project with `npm start` on production environment and `npm run dev` on development environment.
