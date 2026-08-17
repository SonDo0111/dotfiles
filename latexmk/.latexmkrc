$pdf_mode = 4;
$lualatex = 'lualatex -interaction=nonstopmode -synctex=1 %O %S';

$bibtex_use = 2;
$biber = 'biber %O %S';

$clean_ext = 'synctex.gz run.xml bcf fdb_latexmk fls';

if ($^O eq 'MSWin32') {
    $pdf_previewer = 'start "" "C:/Users/Admin/AppData/Local/SumatraPDF/SumatraPDF.exe" '
                    . '-reuse-instance -forward-search %S %L %O';
} else {
    $pdf_previewer = ''okular --unique %O %S#src:%L%S &';
}

$pdf_update_method = 2;
$pdf_update_signal = 'SIGHUP' if $^O ne 'MSWin32';
