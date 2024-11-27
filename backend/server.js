import app from "./app.js";
import dotenv from "dotenv";
import { startIndexer } from "./indexer/index.js";

dotenv.config();
const port = process.env.PORT || 3000;

app.listen(port, () => {
  console.log(`Server is running on port ${port}`);
  startIndexer();
});