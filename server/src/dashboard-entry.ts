#!/usr/bin/env node

import { startDashboardServer } from "./dashboard-server.js";

const port = parseInt(process.env.SDD_DASHBOARD_PORT || "3001", 10);
startDashboardServer(port);
