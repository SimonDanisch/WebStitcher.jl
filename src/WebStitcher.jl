module WebStitcher

using WebPlayer, WebIO, FileIO, Images
using Base.Test, Colors
using CSSUtil

# include("projective_transform.jl")
include("Photostitching.jl")

const redraw = js"""
function redraw(ctx, cross, x, y){

    var rect = ctx.canvas.getBoundingClientRect();

    ctx.clearRect(0, 0, rect.width, rect.height); // Clears the canvas
    ctx.drawImage(ctx.img, 0, 0, ctx.imw, ctx.imh);

    ctx.lineWidth = 1;
    ctx.strokeStyle = \"D9E9FF\";
    var pad = 5;
    if(cross){
        ctx.beginPath();

        ctx.moveTo(x, y + pad);
        ctx.lineTo(x, ctx.imh);

        ctx.moveTo(x, y - pad);
        ctx.lineTo(x, 0);

        ctx.moveTo(x + pad, y);
        ctx.lineTo(ctx.imw, y);

        ctx.moveTo(x - pad, y);
        ctx.lineTo(0, y);

        ctx.stroke();

    }
    ctx.lineWidth = 2;
    ctx.strokeStyle = \"#f00\";
    ctx.lineJoin = "round";

    for(var i = 0; i < ctx.xx.length; i++){
        ctx.beginPath();
        ctx.arc(ctx.xx[i], ctx.yy[i], 5, 5, 180)
        ctx.stroke()
    }
}
"""


function to_pix_coords(scaling, xy...)
    isempty(xy[1]) && return Matrix{Float64}(0, 0)
    N = minimum(length.(xy))
    Float64[xy[j][i]/scaling for i = 1:N, j = 1:2]
end

const mouse_x = WebIO.@js function (canvas, e)
    @var rect = canvas.getBoundingClientRect();
    @var scaleX = canvas.width / rect.width #relationship bitmap vs. element for X
    return (e.clientX - rect.left) * scaleX
end

const mouse_y = WebIO.@js function (canvas, e)
    @var rect = canvas.getBoundingClientRect();
    @var scaleY = canvas.height / rect.height
    return (e.clientY - rect.top) * scaleY
end

function pointpicker(image, id, active, isdone, w; width = 200, num_points = 5)

    imh, imw = size(image)
    scaling = (width / imw)
    newh = round(Int, scaling * imh)

    image_base64 = sprint() do io
        show(Base64EncodePipe(io), MIME"image/png"(), restrict(image))
    end;

    obs = Observable(w, "obs$id", string("data:image/png;base64,", image_base64))

    x_obs = Observable(w, "x_obs$id", [], sync = true)
    y_obs = Observable(w, "y_obs$id", [], sync = true)

    is_active = Observable(w, "is_active$id", active, sync = true)


    ondependencies(w, WebIO.@js function ()

        @var el = this.dom.querySelector($("#$id"))
        @var ctx = el.getContext("2d")

        @var image = @new Image();
        image.onload = function()
            ctx.drawImage(image, 0, 0, $width, $newh);
        end
        image.src = $obs[]

        ctx.img = image;
        ctx.imw = $width;
        ctx.imh = $newh;
        ctx.xx = []
        ctx.yy = []
        ctx.is_active = $is_active[]

        window.redraw = $redraw

    end)

    add_click = WebIO.@js function add_click(e, context)

        @var el = context.dom.querySelector($("#$id"))
        @var ctx = el.getContext("2d")
        @var canvas = ctx.canvas;

        @var x = $(mouse_x)(canvas, e)
        @var y = $(mouse_y)(canvas, e)

        if ctx.is_active && !($isdone[])
            ctx.xx.push(x)
            ctx.yy.push(y)
            $x_obs[] = ctx.xx.concat([])
            $y_obs[] = ctx.yy.concat([])
            window.redraw(ctx, false, 0.0, 0.0)
            $is_active[] = false
            if !$active && ctx.xx.length > $num_points # last image
                $isdone[] = true
            end
        end
    end

    on_mouse = WebIO.@js function on_mouse(e, context)
        @var el = context.dom.querySelector($("#$id"))
        @var ctx = el.getContext("2d")
        @var canvas = ctx.canvas;

        @var x = $(mouse_x)(canvas, e)
        @var y = $(mouse_y)(canvas, e)
        if ctx.is_active && !($isdone[])
            window.redraw(ctx, true, x, y)
        end
    end


    onjs(is_active, WebIO.@js function (val)
        @var div = this.dom.querySelector($("#selection"*id))
        @var el = this.dom.querySelector($("#$id"))
        @var ctx = el.getContext("2d")
        ctx.is_active = val

        if val
            div.style.backgroundColor = "#b0c780"
            if $active # the first image
                div.textContent = "Select a point"
            else
                div.textContent = "Select corresponing point to picture 1"
            end
        else
            div.style.backgroundColor = "#fff"
            div.textContent = ""
            window.redraw(ctx, false, 0.0, 0.0) # clear cross
        end

    end)
    onjs(isdone, WebIO.@js function (val)
        @var div = this.dom.querySelector($("#selection"*id))
        if val
            div.textContent = "DONE!"
            div.style.backgroundColor = "#999"
        end
    end)
    app = dom"canvas"(
        id = id,
        attributes = Dict(
            :width => "$(width)px", :height => "$(newh)px",
        ),
        events = Dict(
            :mouseup => add_click,
            :mousemove => on_mouse
        )
    )

    widget = dom"div"(
        id = "outline"*id,
        app, style = Dict(
            :outline => "2px solid #000",
            :width => "$(width)px", :height => "$(newh)px",
        )
    )

    selected = dom"div"(
        active ? "Select a Point" : "",

        id = "selection"*id,
        style = Dict(
            :fontSize => "200%",
            :textAlign => "center",
            :color => "#fff",
            :padding =>"15px",
            :backgroundColor => active ? "#b0c780" : "#fff",
            :outline => "2px solid #000",
            :width => "$(width)px", :height => "50px"
        )
    )
    points = map((x, y)-> to_pix_coords(scaling, x, y), x_obs, y_obs)
    vbox(selected, widget), points, is_active
end

function getcorrespondences(img1, img2, n; width = 700)
    w = Widget()
    isdone = Observable(w, "isdone", false);
    w1, points1, is_active1 = pointpicker(img1, "test1", true, isdone, w, width = width);
    w2, points2, is_active2 = pointpicker(img2, "test2", false, isdone, w, width = width);
    WebIO.onjs(is_active1, WebIO.@js function (val)
        if !val
            $is_active2[] = true
        end
    end)
    WebIO.onjs(is_active2, WebIO.@js function (val)
        if !val
            $is_active1[] = true
        end
    end)
    (points1, points2), w(vbox(w1, w2))
end

export getcorrespondences, ImageStitcher, stitchImages

end # module
