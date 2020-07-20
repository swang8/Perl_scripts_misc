perl -e '
$f=shift;
$pdf=$f; $pdf=~s/jpeg$/pdf/;
$out="
  <div class=\"col-md-6\">
    <div class=\"thumbnail\">
      <a href=\"$pdf\" target=\"_blank\">
      <img src=\"$f\" style=\"width:100%\">
    </div>
  </div>
";
print $out, "\n"
' $1
