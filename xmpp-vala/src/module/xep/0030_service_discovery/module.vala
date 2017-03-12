using Gee;

using Xmpp.Core;

namespace Xmpp.Xep.ServiceDiscovery {
    private const string NS_URI = "http://jabber.org/protocol/disco";
    public const string NS_URI_INFO = NS_URI + "#info";
    public const string NS_URI_ITEMS = NS_URI + "#items";

    public class Module : XmppStreamModule, Iq.Handler {
        public const string ID = "0030_service_discovery_module";
        public static ModuleIdentity<Module> IDENTITY = new ModuleIdentity<Module>(NS_URI, ID);

        public ArrayList<Identity> identities = new ArrayList<Identity>();

        public Module.with_identity(string category, string type, string? name = null) {
            add_identity(category, type, name);
        }

        public void add_feature(XmppStream stream, string feature) {
            Flag.get_flag(stream).add_own_feature(feature);
        }

        public void add_feature_notify(XmppStream stream, string feature) {
            add_feature(stream, feature + "+notify");
        }

        public void add_identity(string category, string type, string? name = null) {
            identities.add(new Identity(category, type, name));
        }

        [CCode (has_target = false)] public delegate void OnInfoResult(XmppStream stream, InfoResult query_result, Object? store);
        public void request_info(XmppStream stream, string jid, OnInfoResult listener, Object? store) {
            Iq.Stanza iq = new Iq.Stanza.get(new StanzaNode.build("query", NS_URI_INFO).add_self_xmlns());
            iq.to = jid;
            stream.get_module(Iq.Module.IDENTITY).send_iq(stream, iq, on_request_info_response, Tuple.create(listener, store));
        }

        [CCode (has_target = false)] public delegate void OnItemsResult(XmppStream stream, ItemsResult query_result);
        public void request_items(XmppStream stream, string jid, OnItemsResult listener, Object? store) {
            Iq.Stanza iq = new Iq.Stanza.get(new StanzaNode.build("query", NS_URI_ITEMS).add_self_xmlns());
            iq.to = jid;
            stream.get_module(Iq.Module.IDENTITY).send_iq(stream, iq);
        }

        public void on_iq_get(XmppStream stream, Iq.Stanza iq) {
            StanzaNode? query_node = iq.stanza.get_subnode("query", NS_URI_INFO);
            if (query_node != null) {
                send_query_result(stream, iq);
            }
        }

        public void on_iq_set(XmppStream stream, Iq.Stanza iq) { }

        public override void attach(XmppStream stream) {
            Iq.Module.require(stream);
            stream.get_module(Iq.Module.IDENTITY).register_for_namespace(NS_URI_INFO, this);
            stream.add_flag(new Flag());
            add_feature(stream, NS_URI_INFO);
        }

        public override void detach(XmppStream stream) { }

        public static void require(XmppStream stream) {
            if (stream.get_module(IDENTITY) == null) stream.add_module(new ServiceDiscovery.Module());
        }

        public override string get_ns() { return NS_URI; }
        public override string get_id() { return ID; }

        private static void on_request_info_response(XmppStream stream, Iq.Stanza iq, Object o) {
            Tuple<OnInfoResult, Object> tuple = o as Tuple<OnInfoResult, Object>;
            OnInfoResult on_result = tuple.a;
            InfoResult? result = InfoResult.create_from_iq(iq);
            if (result != null) {
                Flag.get_flag(stream).set_entitiy_features(iq.from, result.features);
                on_result(stream, result, tuple.b);
            }
        }

        private void send_query_result(XmppStream stream, Iq.Stanza iq_request) {
            InfoResult query_result = new ServiceDiscovery.InfoResult(iq_request);
            query_result.features = Flag.get_flag(stream).features;
            query_result.identities = identities;
            stream.get_module(Iq.Module.IDENTITY).send_iq(stream, query_result.iq);
        }
    }

    public class Identity {
        public string category { get; set; }
        public string type_ { get; set; }
        public string? name { get; set; }

        public Identity(string category, string type, string? name = null) {
            this.category = category;
            this.type_ = type;
            this.name = name;
        }
    }

    public class Item {
        public string jid;
        public string? name;
        public string? node;

        public Item(string jid, string? name = null, string? node = null) {
            this.jid = jid;
            this.name = name;
            this.node = node;
        }
    }
}