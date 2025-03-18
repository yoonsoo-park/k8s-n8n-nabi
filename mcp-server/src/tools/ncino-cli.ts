/**
 * This file contains the implementation of the ncino-cli tool.
 * It is used to interact with the ncino-cli tool.
 *
 * TODO: Define the schema for the ncino-cli tool.
 * we need to install @ncino/cli to use this tool.
 */

import { z } from "zod";

const ncinoCliSchema = z.object({
  command: z.string(),
});

const ncinoCliTool = {
  name: "ncino-cli",
  description: "A tool to interact with the ncino-cli tool.",
  parameters: ncinoCliSchema,
};

export default ncinoCliTool;
