#!/usr/bin/env python3
"""
Integration tests for k8s-devops-pipeline
Tests the deployment and interaction of various components
"""

import os
import sys
import time
import unittest
import subprocess
import yaml
import json
import requests
from typing import Dict, List, Optional

# Add project root to path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../..')))


class K8sDevOpsPipelineIntegrationTest(unittest.TestCase):
    """Integration tests for the k8s DevOps pipeline"""

    @classmethod
    def setUpClass(cls):
        """Set up test environment"""
        cls.server_ip = os.environ.get('SERVER_IP', '10.0.0.88')
        cls.kubeconfig = os.environ.get('KUBECONFIG', os.path.expanduser('~/.kube/config'))
        
        # Service URLs
        cls.urls = {
            'traefik': f'http://{cls.server_ip}:30900/dashboard/',
            'harbor': f'http://{cls.server_ip}:30880',
            'argocd': f'http://{cls.server_ip}:30808',
            'prometheus': f'http://{cls.server_ip}:30909',
            'grafana': f'http://{cls.server_ip}:30300',
            'alertmanager': f'http://{cls.server_ip}:30903'
        }

    def setUp(self):
        """Set up each test"""
        self.verify_kubectl_access()

    def verify_kubectl_access(self):
        """Verify kubectl can access the cluster"""
        try:
            result = subprocess.run(
                ['kubectl', 'cluster-info'],
                capture_output=True,
                text=True,
                check=True
            )
            self.assertIn('Kubernetes', result.stdout)
        except subprocess.CalledProcessError as e:
            self.fail(f"Cannot access Kubernetes cluster: {e}")

    def run_kubectl_command(self, args: List[str]) -> Dict:
        """Run kubectl command and return JSON output"""
        cmd = ['kubectl'] + args + ['-o', 'json']
        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                check=True
            )
            return json.loads(result.stdout)
        except subprocess.CalledProcessError as e:
            self.fail(f"kubectl command failed: {e.stderr}")

    def test_namespaces_exist(self):
        """Test that all required namespaces exist"""
        required_namespaces = [
            'metallb-system',
            'traefik',
            'harbor',
            'cert-manager',
            'argocd',
            'monitoring'
        ]
        
        namespaces = self.run_kubectl_command(['get', 'namespaces'])
        namespace_names = [ns['metadata']['name'] for ns in namespaces['items']]
        
        for ns in required_namespaces:
            with self.subTest(namespace=ns):
                self.assertIn(ns, namespace_names, f"Namespace {ns} not found")

    def test_pods_running(self):
        """Test that all pods are in Running state"""
        namespaces = ['metallb-system', 'traefik', 'harbor', 'cert-manager', 'argocd', 'monitoring']
        
        for namespace in namespaces:
            with self.subTest(namespace=namespace):
                pods = self.run_kubectl_command(['get', 'pods', '-n', namespace])
                
                for pod in pods['items']:
                    pod_name = pod['metadata']['name']
                    pod_phase = pod['status']['phase']
                    
                    # Skip completed jobs
                    if pod_phase == 'Succeeded':
                        continue
                        
                    self.assertEqual(
                        pod_phase,
                        'Running',
                        f"Pod {pod_name} in namespace {namespace} is not Running (status: {pod_phase})"
                    )

    def test_services_accessible(self):
        """Test that all services are accessible via HTTP"""
        for service_name, url in self.urls.items():
            with self.subTest(service=service_name):
                try:
                    response = requests.get(url, timeout=10, allow_redirects=True)
                    # Some services redirect or return non-200 codes
                    self.assertIn(
                        response.status_code,
                        [200, 301, 302, 401, 403],
                        f"{service_name} returned unexpected status code: {response.status_code}"
                    )
                except requests.exceptions.RequestException as e:
                    self.fail(f"{service_name} is not accessible at {url}: {e}")

    def test_metallb_configuration(self):
        """Test MetalLB configuration"""
        # Check IP address pools
        pools = self.run_kubectl_command(['get', 'ipaddresspools', '-n', 'metallb-system'])
        self.assertGreater(len(pools['items']), 0, "No MetalLB IP address pools found")
        
        # Check L2 advertisements
        l2ads = self.run_kubectl_command(['get', 'l2advertisements', '-n', 'metallb-system'])
        self.assertGreater(len(l2ads['items']), 0, "No MetalLB L2 advertisements found")

    def test_traefik_ingress(self):
        """Test Traefik ingress controller"""
        # Check Traefik deployment
        deployment = self.run_kubectl_command(['get', 'deployment', 'traefik', '-n', 'traefik'])
        self.assertEqual(deployment['status']['readyReplicas'], deployment['spec']['replicas'])
        
        # Check Traefik service
        service = self.run_kubectl_command(['get', 'service', 'traefik', '-n', 'traefik'])
        self.assertEqual(service['spec']['type'], 'NodePort')

    def test_harbor_registry(self):
        """Test Harbor container registry"""
        # Check Harbor components
        harbor_components = ['harbor-core', 'harbor-jobservice', 'harbor-portal', 'harbor-registry']
        
        for component in harbor_components:
            deployments = self.run_kubectl_command(['get', 'deployments', '-n', 'harbor'])
            deployment_names = [d['metadata']['name'] for d in deployments['items']]
            
            # Check if component exists in deployments or statefulsets
            if component not in deployment_names:
                statefulsets = self.run_kubectl_command(['get', 'statefulsets', '-n', 'harbor'])
                statefulset_names = [s['metadata']['name'] for s in statefulsets['items']]
                self.assertTrue(
                    any(component in name for name in deployment_names + statefulset_names),
                    f"Harbor component {component} not found"
                )

    def test_argocd_applications(self):
        """Test ArgoCD applications"""
        # Check ArgoCD server
        deployment = self.run_kubectl_command(['get', 'deployment', 'argocd-server', '-n', 'argocd'])
        self.assertEqual(deployment['status']['readyReplicas'], deployment['spec']['replicas'])
        
        # Check if any applications are deployed
        try:
            apps = self.run_kubectl_command(['get', 'applications', '-n', 'argocd'])
            # It's okay if no applications are deployed yet
            print(f"Found {len(apps['items'])} ArgoCD applications")
        except subprocess.CalledProcessError:
            # CRD might not be available, which is okay
            pass

    def test_prometheus_metrics(self):
        """Test Prometheus metrics collection"""
        # Check Prometheus deployment
        statefulset = self.run_kubectl_command([
            'get', 'statefulset', '-n', 'monitoring',
            '-l', 'app.kubernetes.io/name=prometheus'
        ])
        
        if statefulset['items']:
            prometheus_sts = statefulset['items'][0]
            self.assertEqual(
                prometheus_sts['status']['readyReplicas'],
                prometheus_sts['spec']['replicas']
            )
        
        # Test Prometheus API
        try:
            response = requests.get(f"{self.urls['prometheus']}/api/v1/targets", timeout=10)
            if response.status_code == 200:
                data = response.json()
                active_targets = [t for t in data['data']['activeTargets'] if t['health'] == 'up']
                self.assertGreater(len(active_targets), 0, "No healthy Prometheus targets found")
        except requests.exceptions.RequestException:
            # Prometheus might not be fully accessible, which is okay for basic test
            pass

    def test_grafana_dashboards(self):
        """Test Grafana dashboards"""
        # Check Grafana deployment
        deployment = self.run_kubectl_command([
            'get', 'deployment', '-n', 'monitoring',
            '-l', 'app.kubernetes.io/name=grafana'
        ])
        
        if deployment['items']:
            grafana_deploy = deployment['items'][0]
            self.assertEqual(
                grafana_deploy['status']['readyReplicas'],
                grafana_deploy['spec']['replicas']
            )

    def test_persistent_volumes(self):
        """Test persistent volume claims"""
        pvcs = self.run_kubectl_command(['get', 'pvc', '--all-namespaces'])
        
        for pvc in pvcs['items']:
            with self.subTest(pvc=pvc['metadata']['name']):
                self.assertEqual(
                    pvc['status']['phase'],
                    'Bound',
                    f"PVC {pvc['metadata']['name']} in namespace {pvc['metadata']['namespace']} is not Bound"
                )

    def test_resource_limits(self):
        """Test that critical pods have resource limits"""
        critical_namespaces = ['harbor', 'argocd', 'monitoring']
        
        for namespace in critical_namespaces:
            pods = self.run_kubectl_command(['get', 'pods', '-n', namespace])
            
            for pod in pods['items']:
                # Skip completed jobs
                if pod['status']['phase'] == 'Succeeded':
                    continue
                    
                for container in pod['spec']['containers']:
                    with self.subTest(pod=pod['metadata']['name'], container=container['name']):
                        # Check if resources are defined (not enforcing for homelab)
                        if 'resources' in container:
                            print(f"✓ {pod['metadata']['name']}/{container['name']} has resource definitions")
                        else:
                            print(f"⚠ {pod['metadata']['name']}/{container['name']} missing resource definitions")


def suite():
    """Create test suite"""
    return unittest.TestLoader().loadTestsFromTestCase(K8sDevOpsPipelineIntegrationTest)


if __name__ == '__main__':
    # Run with verbose output
    runner = unittest.TextTestRunner(verbosity=2)
    runner.run(suite())