module now.conv;


import std.format;


long toLong(string s)
{
    long result;
    if (s.length >= 2 && s[0..2] == "0x")
    {
        string sub = s[2..$];
        sub.formattedRead("%x", result);
    }
    else
    {
        s.formattedRead("%d", result);
    }
    return result;
}
