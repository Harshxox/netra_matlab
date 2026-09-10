function label = gradeLabel(grade)
%GRADELABEL  Map DR grade 0-4 to its clinical name.
    labels = {'No DR','Mild','Moderate','Severe','Proliferative DR'};
    grade  = max(0, min(4, round(grade)));
    label  = labels{grade + 1};
end
