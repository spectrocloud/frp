package plugin

import (
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"io"
	"io/ioutil"
	"net"
	"net/http"
	"net/http/httputil"
	"strings"

	frpNet "github.com/fatedier/frp/pkg/util/net"
)

const PluginHTTPS2HTTPSCerts = "https2https_certs"

func init() {
	Register(PluginHTTPS2HTTPSCerts, NewHTTPS2HTTPSCertsPlugin)
}

type HTTPS2HTTPSCertsPlugin struct {
	crtPath            string
	keyPath            string
	localServerCAPath  string
	localServerCrtPath string
	localServerKeyPath string
	hostHeaderRewrite  string
	localAddr          string
	headers            map[string]string

	l *Listener
	s *http.Server
}

func NewHTTPS2HTTPSCertsPlugin(params map[string]string) (Plugin, error) {
	crtPath := params["plugin_crt_path"]
	keyPath := params["plugin_key_path"]
	localServerCAPath := params["plugin_local_server_ca_path"]
	localServerCrtPath := params["plugin_local_server_crt_path"]
	localServerKeyPath := params["plugin_local_server_key_path"]
	localAddr := params["plugin_local_addr"]
	hostHeaderRewrite := params["plugin_host_header_rewrite"]

	headers := make(map[string]string)
	for k, v := range params {
		if !strings.HasPrefix(k, "plugin_header_") {
			continue
		}
		if k = strings.TrimPrefix(k, "plugin_header_"); k != "" {
			headers[k] = v
		}
	}

	if crtPath == "" {
		return nil, fmt.Errorf("plugin_crt_path is required")
	}
	if keyPath == "" {
		return nil, fmt.Errorf("plugin_key_path is required")
	}
	if localServerCAPath == "" {
		return nil, fmt.Errorf("plugin_local_server_ca_path is required")
	}
	if localServerCrtPath == "" {
		return nil, fmt.Errorf("plugin_local_server_crt_path is required")
	}
	if localServerKeyPath == "" {
		return nil, fmt.Errorf("plugin_local_server_key_path is required")
	}
	if localAddr == "" {
		return nil, fmt.Errorf("plugin_local_addr is required")
	}

	listener := NewProxyListener()

	p := &HTTPS2HTTPSCertsPlugin{
		crtPath:            crtPath,
		keyPath:            keyPath,
		localServerCAPath:  localServerCAPath,
		localServerCrtPath: localServerCrtPath,
		localServerKeyPath: localServerKeyPath,
		localAddr:          localAddr,
		hostHeaderRewrite:  hostHeaderRewrite,
		headers:            headers,
		l:                  listener,
	}

	localServerTLSConfig, err := genTLSConfig(localServerCrtPath, localServerKeyPath, localServerCAPath)
	if err != nil {
		return nil, fmt.Errorf("gen local server TLS config error: %v", err)
	}

	tr := &http.Transport{
		TLSClientConfig: localServerTLSConfig,
	}

	rp := &httputil.ReverseProxy{
		Director: func(req *http.Request) {
			req.URL.Scheme = "https"
			req.URL.Host = p.localAddr
			if p.hostHeaderRewrite != "" {
				req.Host = p.hostHeaderRewrite
			}
			for k, v := range p.headers {
				req.Header.Set(k, v)
			}
		},
		Transport: tr,
	}

	p.s = &http.Server{
		Handler: rp,
	}

	tlsConfig, err := genTLSConfig(crtPath, keyPath, "")
	if err != nil {
		return nil, fmt.Errorf("gen local server TLS config error: %v", err)
	}
	ln := tls.NewListener(listener, tlsConfig)

	go p.s.Serve(ln)
	return p, nil
}

func genTLSConfig(crtPath, keyPath, caPath string) (*tls.Config, error) {
	cert, err := tls.LoadX509KeyPair(crtPath, keyPath)
	if err != nil {
		return nil, err
	}

	config := &tls.Config{Certificates: []tls.Certificate{cert}}

	if caPath != "" {
		var rpool *x509.CertPool
		if pemBytes, err := ioutil.ReadFile(caPath); err == nil {
			rpool = x509.NewCertPool()
			rpool.AppendCertsFromPEM(pemBytes)
		}
		config.RootCAs = rpool
	}

	return config, nil
}

func (p *HTTPS2HTTPSCertsPlugin) Handle(conn io.ReadWriteCloser, realConn net.Conn, extraBufToLocal []byte) {
	wrapConn := frpNet.WrapReadWriteCloserToConn(conn, realConn)
	p.l.PutConn(wrapConn)
}

func (p *HTTPS2HTTPSCertsPlugin) Name() string {
	return PluginHTTPS2HTTPSCerts
}

func (p *HTTPS2HTTPSCertsPlugin) Close() error {
	if err := p.s.Close(); err != nil {
		return err
	}
	return nil
}
