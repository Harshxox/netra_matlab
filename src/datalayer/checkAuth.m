function [ok, role, displayName] = checkAuth(username, password)
%CHECKAUTH  Prototype credential check for the Netra app.
%
%   [ok, role, displayName] = checkAuth('admin', 'netra2026')
%
%   role is 'admin' or 'operator'. Prototype only - credentials are defined
%   here, not hashed or stored in a real auth system.
%
%   ---- CREDENTIALS ----------------------------------------------------
%     admin      / netra2026      -> admin  (district health officer console)
%     phc        / phc2026        -> operator (health worker at the PHC)
%     doctor     / doctor2026     -> operator
%   -------------------------------------------------------------------

    users = { ...
        'admin',  'netra2026',  'admin',    'District Health Officer'; ...
        'phc',    'phc2026',    'operator', 'PHC Health Worker'; ...
        'doctor', 'doctor2026', 'operator', 'Screening Operator' };

    ok = false; role = ''; displayName = '';
    u = lower(strtrim(char(string(username))));
    p = char(string(password));

    for i = 1:size(users,1)
        if strcmp(u, users{i,1}) && strcmp(p, users{i,2})
            ok = true; role = users{i,3}; displayName = users{i,4};
            return
        end
    end
end
