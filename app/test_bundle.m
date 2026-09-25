function test_bundle()
%TEST_BUNDLE  Verify buildAppHtml produces a valid self-contained HTML.
    hp = buildAppHtml();
    s = dir(hp);
    c = fileread(hp);
    fprintf('bundle: %s  (%d KB)\n', hp, round(s.bytes/1024));
    assert(contains(c, '<style>'),               'no inline <style>');
    assert(contains(c, '.lg-brand'),             'CSS not inlined (.lg-brand missing)');
    assert(contains(c, 'function setup'),         'JS not inlined');
    assert(~contains(c, 'href="dashboard.css"'),  'stale <link> still present');
    assert(~contains(c, 'src="dashboard.js"'),    'stale <script src> still present');
    assert(contains(c, 'id="loginView"'),         'HTML body missing');
    fprintf('OK - self-contained, %d chars\n', numel(c));
end
