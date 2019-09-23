package com.pressir.base;

import com.google.common.net.HostAndPort;
import com.pressir.base.transport.TTransportFactory;
import com.pressir.monitor.Monitor;
import org.apache.thrift.TServiceClient;
import org.apache.thrift.TServiceClientFactory;
import org.apache.thrift.protocol.TProtocol;
import org.apache.thrift.protocol.TProtocolFactory;
import org.apache.thrift.transport.TTransport;
import org.apache.thrift.transport.TTransportException;

import java.lang.reflect.Method;
import java.util.Objects;

/**
 * @ClassName ServiceClientInvocation
 * @Description TODO
 * @Author pressir
 * @Date 2019-09-19 21:09
 */
public class ServiceClientInvocation<T extends TServiceClient> {

    private final TServiceClientFactory<T> serviceClientFactory;

    private final TProtocolFactory protocolFactory;

    private final TTransportFactory transportFactory;

    private final HostAndPort endpoint;

    public ServiceClientInvocation(TServiceClientFactory<T> serviceClientFactory, TProtocolFactory protocolFactory, TTransportFactory transportFactory, HostAndPort endpoint) {
        this.serviceClientFactory = Objects.requireNonNull(serviceClientFactory);
        this.protocolFactory = Objects.requireNonNull(protocolFactory);
        this.transportFactory = Objects.requireNonNull(transportFactory);
        this.endpoint = Objects.requireNonNull(endpoint);
    }

    public void invoke(Method method, Object... args) {
        String keyword = method.getName();
        T client = this.getClient();
        try {
            long startAt = System.currentTimeMillis();
            Monitor.onConnect(keyword);
            this.open(client);
            Monitor.onSend(keyword);
            method.invoke(client, args);
            Monitor.onReceived(keyword, (int) (System.currentTimeMillis() - startAt));
        } catch (Exception e) {
            Monitor.onError(keyword, e);
        } finally {
            this.close(client);
        }
    }

    private T getClient() {
        TTransport transport = this.transportFactory.getTransport(this.endpoint);
        TProtocol protocol = this.protocolFactory.getProtocol(transport);
        return this.serviceClientFactory.getClient(protocol);
    }

    private void open(T client) throws TTransportException {
        TProtocol iprot = client.getInputProtocol();
        TTransport itrans = iprot.getTransport();
        if (!itrans.isOpen()) {
            itrans.open();
        }
        TProtocol oprot = client.getOutputProtocol();
        if (oprot == iprot) {
            return;
        }
        TTransport otrans = oprot.getTransport();
        if (otrans == itrans) {
            return;
        }
        if (!otrans.isOpen()) {
            otrans.open();
        }
    }

    private void close(T client) {
        TProtocol iprot = client.getInputProtocol();
        TProtocol oprot = client.getOutputProtocol();
        if (oprot == iprot) {
            iprot.getTransport().close();
            return;
        }
        TTransport itrans = iprot.getTransport();
        TTransport otrans = oprot.getTransport();
        if (otrans == itrans) {
            itrans.close();
            return;
        }
        try {
            itrans.close();
            otrans.close();
        } finally {
            otrans.close();
        }
    }
}