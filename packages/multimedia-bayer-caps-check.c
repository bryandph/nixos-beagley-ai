/* Inspect factory pad templates without instantiating hardware-backed elements. */
#include <assert.h>
#include <gst/gst.h>
#include <stdio.h>

extern int gst_format_to_tivx_raw_format(const gchar *format);

static GstCaps *factory_caps(const char *name, GstPadDirection direction)
{
    GstElementFactory *factory = gst_element_factory_find(name);
    assert(factory != NULL);
    GstCaps *result = gst_caps_new_empty();
    for (const GList *item = gst_element_factory_get_static_pad_templates(factory);
         item; item = item->next) {
        GstStaticPadTemplate *pad = item->data;
        if (pad->direction == direction)
            gst_caps_append(result, gst_static_caps_get(&pad->static_caps));
    }
    gst_object_unref(factory);
    return result;
}

int main(int argc, char **argv)
{
    gst_init(&argc, &argv);
    GstCaps *source = factory_caps("v4l2src", GST_PAD_SRC);
    GstCaps *sink = factory_caps("tiovxisp", GST_PAD_SINK);
    const char *orders[] = {"bggr", "gbrg", "grbg", "rggb"};
    for (unsigned int index = 0; index < 4; index++) {
        char legacy[16], native[16], text[160];
        snprintf(legacy, sizeof legacy, "%s10", orders[index]);
        snprintf(native, sizeof native, "%s10le", orders[index]);
        snprintf(text, sizeof text, "video/x-bayer,format=%s,width=640,height=480,framerate=30/1", native);
        GstCaps *mode = gst_caps_from_string(text);
        assert(gst_caps_can_intersect(source, mode));
        assert(gst_caps_can_intersect(sink, mode));
        assert(gst_format_to_tivx_raw_format(native) >= 0);
        assert(gst_format_to_tivx_raw_format(native) == gst_format_to_tivx_raw_format(legacy));
        gst_caps_unref(mode);
    }
    gst_caps_unref(source);
    gst_caps_unref(sink);
    puts("V4L2/ISP RAW10 Bayer caps and container parsing agree for all four orders");
    return 0;
}
