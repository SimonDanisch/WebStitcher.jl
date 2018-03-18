isinstalled(pkg) = isdir(Pkg.dir(pkg))
function installgizmo(pkg)
    isinstalled(pkg) || Pkg.clone("https://github.com/JuliaGizmos/$(pkg).jl")
end
function installweb(pkg)
    if isinstalled(pkg)
        Pkg.checkout(pkg)
    else
        Pkg.clone("https://github.com/SimonDanisch/$(pkg).jl")
    end
end

installweb("WebWidgets")
installweb("WebPlayer")
installweb("WebStitcher")

installgizmo("WebIO"); Pkg.checkout("WebIO", "legacy")
Pkg.checkout("Observables")
installgizmo("Vue");Pkg.checkout("Vue", "legacy")
installgizmo("CSSUtil")
installgizmo("InteractNext");Pkg.checkout("InteractNext", "legacy")
asset_dir = Pkg.dir("WebStitcher", "assets")
wio_asset_dir = Pkg.dir("WebIO", "assets")
for elem in readdir(asset_dir)
    file_source = joinpath(asset_dir, elem)
    file_target = joinpath(wio_asset_dir, elem)
    if !(isfile(file_target) || isdir(file_target))
        try
            println("Copying: $file_target")
            cp(file_source, file_target)
        catch e
            warn(e)
        end
    end
end
