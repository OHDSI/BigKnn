# Format and check code:
OhdsiRTools::formatRFolder()
OhdsiRTools::checkUsagePackage("BigKnn")
OhdsiRTools::updateCopyrightYearFolder()

# Create manual:
shell("rm extras/BigKnn.pdf")
shell("R CMD Rd2pdf ./ --output=extras/BigKnn.pdf")
