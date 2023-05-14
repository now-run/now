module now.env_vars;


import std.process : environment;

import now.nodes;


Dict envVars;


void loadEnvVars()
{
    envVars = new Dict();
    foreach(key, value; environment.toAA())
    {
        envVars[key] = new String(value);
    }
}
